require "test_helper"

# Tool descriptions and retrieval parameters are versioned with their prompt (Langfuse prompt config), so a new
# version can change them, an experiment can measure it, and a rollout can serve it, without a deploy.
class PromptVariantTest < ActiveSupport::TestCase
  include TracingTestHelper

  setup { Rails.cache = ActiveSupport::Cache::MemoryStore.new }
  teardown { Rails.cache = ActiveSupport::Cache::NullStore.new }

  test "a block can use another version of a prompt by label or number; production elsewhere and afterwards" do
    with_langfuse do
      stub_prompt("feature-judge", "label=production", version: 2)
      stub_prompt("feature-judge", "label=candidate", version: 5)
      stub_prompt("feature-judge", "version=3", version: 3)

      assert_equal 5, Prompt.using({ "feature-judge" => "candidate" }) { Prompt.fetch("feature-judge").version }
      assert_equal 3, Prompt.using({ "feature-judge" => 3 }) { Prompt.fetch("feature-judge").version }
      assert_equal 2, Prompt.fetch("feature-judge").version
    end
  end

  test "the assistant's tool descriptions come from the product-agent version it runs" do
    with_langfuse do
      stub_request(:get, %r{langfuse\.test/api/public/v2/prompts/}).to_return(status: 404, body: "{}") # WebMock tries later stubs first
      stub_prompt("product-agent", "label=production", version: 1)
      stub_prompt("product-agent", "label=candidate", version: 2, config: { tools: { search_feedback: "Finds what customers said, version two." } })

      Prompt.using({ "product-agent" => "candidate" }) { ask_assistant("What do customers say about PDF export?") }
    end

    tools = JSON.parse(llm_requests("oxybot-assistant").first.body).fetch("tools").to_h { |tool| [ tool.dig("function", "name"), tool.dig("function", "description") ] }
    assert_equal "Finds what customers said, version two.", tools["search_feedback"]
    assert_equal Prompt.file_config("product-agent").dig("tools", "list_features"), tools["list_features"], "keys the version leaves out come from the file"
  end

  test "search_feedback returns as many insights as the version's retrieval limit says, and ignores invalid values" do
    create_insights
    with_langfuse do
      stub_prompt("product-agent", "label=production", version: 1, config: { retrieval: { limit: 1 } })
      stub_prompt("product-agent", "label=candidate", version: 2, config: { retrieval: { limit: "all of them", rrf_k: -4 } })

      assert_equal 1, search_feedback("PDF export").size
      assert_equal 10, Prompt.using({ "product-agent" => "candidate" }) { Prompt.retrieval("product-agent") }["limit"], "an invalid limit keeps the file's"
      assert_equal 60, Prompt.using({ "product-agent" => "candidate" }) { Prompt.retrieval("product-agent") }["rrf_k"]
    end
  end

  test "fusion weights decide which list wins: weight 0 leaves only the other list's order" do
    account = accounts(:acme)
    create_insights
    space, vectors = EmbeddingSpace.embed([ "PDF export" ], task: :query)
    ranking = ->(tuning) { account.insights.ranked("PDF export", mode: :hybrid, vector: vectors.first, space: space, tuning: tuning).map(&:id) }

    text_only = account.insights.ranked("PDF export", mode: :text, vector: nil, space: nil).map(&:id)
    vector_only = account.insights.ranked("PDF export", mode: :vector, vector: vectors.first, space: space).map(&:id)

    assert_equal text_only, ranking.call("vector_weight" => 0.0).first(text_only.size)
    assert_equal vector_only.first(3), ranking.call("text_weight" => 0.0).first(3)
    assert_not_equal text_only, vector_only.first(text_only.size), "the two lists must differ for this test to mean anything"
  end

  test "matching offers the judge as many features as feature-judge's retrieval limit" do
    insight = accounts(:acme).insights.new(product: products(:reports), summary: "Reports as PDF", quote: "PDF please")

    assert_equal 1, Prompt.using({}, retrieval: { "limit" => 1 }) { insight.match_candidates.size }
    assert_operator insight.match_candidates.size, :>, 1
  end

  test "an evaluation run names its variant: model, prompt version and retrieval overrides" do
    with_langfuse do
      stub_request(:get, %r{langfuse\.test/api/public/v2/prompts/}).to_return(status: 404, body: "{}")
      stub_prompt("feature-judge", "label=candidate", version: 7)
      evaluation = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme), prompt: "candidate", retrieval: { "limit" => "2" })

      assert_equal({ "model" => "oxybot-haiku", "prompt" => "feature-judge@v7" }, evaluation.variant.except("retrieval"))
      assert_equal 2, evaluation.variant.dig("retrieval", "limit")
      assert_match(/\Amatching oxybot-haiku feature-judge@v7 limit=2 /, evaluation.run_name)
    end
  end

  private

  def stub_prompt(name, query, version:, config: {})
    stub_request(:get, "http://langfuse.test/api/public/v2/prompts/#{name}?#{query}")
      .to_return(body: { name: name, type: "text", version: version, prompt: Prompt.from_file(name).text, config: config }.to_json)
  end

  def ask_assistant(question)
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))
    conversation.ask(question)
    perform_enqueued_jobs(only: GenerateReplyJob)
  end

  def search_feedback(query)
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))
    turn = Conversation::Turn.new(conversation.messages.create!(role: "assistant", status: "thinking"))
    SearchFeedbackTool.new(turn).execute(query: query)[:insights]
  end

  def create_insights
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    insights = [ "PDF export of reports for the board", "Export dashboards to PDF", "Dark mode for dashboards", "Slack alerts when a metric drops",
                 "Printable board pack every month" ].map do |text|
      note.insights.create!(account: accounts(:acme), product: products(:reports), quote: text, summary: text)
    end
    Insight.embed_all(insights)
  end
end
