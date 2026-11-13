# A stand-in for LiteLLM that speaks the same OpenAI-compatible API (/v1/chat/completions, /v1/embeddings),
# so the app runs end to end without API keys: RubyLLM, tool calls, schemas and jobs all take their real path,
# only the "model" is a set of deterministic heuristics.
#
# Development mounts it at /mock_llm when LITELLM_URL is blank (config/routes.rb). Tests route the
# http://mock-llm.test host to it through WebMock (test/test_helper.rb).
#
# It answers per LiteLLM alias:
#   flint-extract  splits feedback into sentences and assigns each to the product with the most shared words
#   flint-judge    picks the candidate feature with the most shared words, or none below two
#   flint-assistant    calls one tool chosen by keywords, then writes the answer from the tool's JSON
#   flint-embed    hashed bag of word stems, so texts sharing words are close in cosine distance
class MockLlm
  DIMENSIONS = 1536
  STOP_WORDS = %w[
    the and for with that this from have has are was were not but you your our they them when what which
    there their about would could should into than then also just very more most some only will can
    oraz jest nie się sie jak ale dla przy tak już juz bardzo mamy może moze tego tylko które ktore
  ].to_set.freeze
  URGENT = /\b(block|blocker|blocking|cannot|can't|churn|cancel|urgent|critical|losing|lost|blokuje|pilne|nie możemy|rezygn)/i
  PLEASANTRY = /\A\s*(hi|hello|hey|thanks|thank you|cheers|regards|best|cześć|dzień dobry|dzięki|pozdrawiam)\b/i

  def call(env)
    request = Rack::Request.new(env)
    body = JSON.parse(request.body.read)

    case request.path_info
    when %r{/chat/completions\z} then json(chat_completion(body))
    when %r{/embeddings\z} then json(embeddings(body))
    else [404, { "content-type" => "application/json" }, [{ error: "not found" }.to_json]]
    end
  end

  def self.vector(text)
    vector = Array.new(DIMENSIONS, 0.0)
    stems(text).each { |stem| vector[Zlib.crc32(stem) % DIMENSIONS] += 1.0 }
    vector[0] = 0.01 if vector.all?(&:zero?)
    norm = Math.sqrt(vector.sum { |x| x * x })
    vector.map { |x| (x / norm).round(6) }
  end

  # Lowercased, transliterated words of 3+ letters without stop words, cut to 5 letters as a crude stemmer
  def self.stems(text)
    I18n.transliterate(text.to_s.downcase).scan(/[a-z0-9]{3,}/).reject { |word| STOP_WORDS.include?(word) }.map { |word| word[0, 5] }
  end

  private

  def json(payload)
    [200, { "content-type" => "application/json" }, [payload.to_json]]
  end

  def chat_completion(body)
    message = case body["model"]
    when "flint-extract" then { role: "assistant", content: extract(body["messages"]).to_json }
    when "flint-judge" then { role: "assistant", content: judge(body["messages"]).to_json }
    when "flint-assistant" then assistant(body["messages"], Array(body["tools"]))
    else { role: "assistant", content: "Mock model has no behavior for #{body["model"]}." }
    end

    {
      id: "chatcmpl-mock-#{SecureRandom.hex(4)}", object: "chat.completion", created: Time.now.to_i, model: body["model"],
      choices: [{ index: 0, message: message, finish_reason: message[:tool_calls] ? "tool_calls" : "stop" }],
      usage: { prompt_tokens: body["messages"].to_json.size / 4, completion_tokens: message.to_json.size / 4, total_tokens: 0 }
    }
  end

  def embeddings(body)
    inputs = Array(body["input"])
    { object: "list", model: body["model"], usage: { prompt_tokens: 0, total_tokens: 0 },
      data: inputs.each_with_index.map { |text, index| { object: "embedding", index: index, embedding: self.class.vector(text) } } }
  end

  # The prompt lists products as "- slug: Name. Description" and ends with the feedback after "Feedback:".
  def extract(messages)
    prompt = messages.map { |message| content_text(message) }.join("\n")
    products = prompt.scan(/^- ([a-z0-9-]+): (.+)$/).to_h
    feedback = prompt.split(/^Feedback:\s*$/).last.to_s

    insights = feedback.split(/(?<=[.!?])\s+|\n+/).map(&:strip).filter_map do |sentence|
      next if sentence.split.size < 5 || sentence.match?(PLEASANTRY)

      product = products.max_by { |slug, text| overlap(sentence, "#{slug} #{text}") }&.first
      { product_slug: product, quote: sentence, summary: sentence.delete_suffix(".").truncate(110),
        urgency: sentence.match?(URGENT) ? "high" : "medium", customer_name: nil }
    end
    { insights: insights }
  end

  # The prompt holds "Insight: ..." and candidates as "- [12] Title: description".
  def judge(messages)
    prompt = messages.map { |message| content_text(message) }.join("\n")
    insight = prompt[/^Insight: (.+)$/, 1].to_s
    candidates = prompt.scan(/^- \[(\d+)\] (.+)$/)
    id, text = candidates.max_by { |_id, candidate| overlap(insight, candidate) }
    shared = text ? overlap(insight, text) : 0

    if shared >= 2
      { feature_id: id.to_i, confidence: [0.5 + 0.1 * shared, 0.95].min.round(2), reason: "Shares #{shared} key terms with the feature." }
    else
      { feature_id: nil, confidence: 0.4, reason: "No candidate describes the same need." }
    end
  end

  # First request of a turn: call one tool. After the tool result: answer from its JSON.
  def assistant(messages, tools)
    last = messages.last
    return { role: "assistant", content: answer_from(content_text(last)) } if last["role"] == "tool"

    question = content_text(messages.reverse.find { |message| message["role"] == "user" })
    names = tools.map { |tool| tool.dig("function", "name") }
    name, arguments = pick_tool(question, names)
    return { role: "assistant", content: "I can only answer questions about your product feedback." } unless name

    { role: "assistant", content: nil,
      tool_calls: [{ id: "call_#{SecureRandom.hex(4)}", type: "function", function: { name: name, arguments: arguments.to_json } }] }
  end

  def pick_tool(question, names)
    text = question.downcase
    if text.match?(/\b(top|most|rank|priorit|demand|arr|revenue|biggest|najwi|przych|priorytet)/) && names.include?("feature_demand")
      ["feature_demand", {}]
    elsif text.match?(/\b(features?|backlog|roadmap|funkcj|planned)\b/) && names.include?("list_features")
      ["list_features", {}]
    elsif names.include?("search_feedback")
      ["search_feedback", { query: question }]
    end
  end

  def answer_from(tool_json)
    data = JSON.parse(tool_json)
    rows = data.is_a?(Hash) ? (data["insights"] || data["features"] || []) : data
    return "I could not use that data: #{data["error"]}" if data.is_a?(Hash) && data["error"]
    return "I found nothing in your feedback about that." if rows.empty?

    lines = rows.first(6).map do |row|
      if row.key?("insight_count")
        ids = Array(row["sample_insight_ids"]).map { |id| "[insight:#{id}]" }.join(" ")
        arr = row["arr"] ? ", #{row["arr"]} ARR" : ""
        "- **#{row["title"]}** (#{row["product"]}): #{row["insight_count"]} insights from #{row["customer_count"]} customers#{arr} #{ids}"
      elsif row.key?("quote")
        who = [row["customer"], row["arr"]].compact.join(", ")
        "- #{row["summary"]}#{" (#{who})" if who.present?} [insight:#{row["id"]}]"
      else
        "- **#{row["title"]}** (#{row["product"]}, #{row["status"]})"
      end
    end
    "Here is what I found (mock model, so this is a plain listing):\n\n#{lines.join("\n")}"
  rescue JSON::ParserError
    "The tool returned something I could not read."
  end

  def overlap(a, b)
    (self.class.stems(a).to_set & self.class.stems(b).to_set).size
  end

  def content_text(message)
    content = message && message["content"]
    content.is_a?(Array) ? content.filter_map { |part| part["text"] }.join("\n") : content.to_s
  end
end
