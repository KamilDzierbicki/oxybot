# Configures the Langfuse project to work with OxyBot and LiteLLM (bin/rails langfuse:setup, safe to run again):
#
# - an LLM connection to the LiteLLM gateway, so Langfuse's evaluators and playground use the same model aliases,
#   budgets and cost tracking as the app
# - two LLM-as-judge evaluators on OxyBot's own root spans: is an assistant answer supported by the quotes it cites,
#   and do extracted insights stay true to the feedback
# - rules that run them on new traces. Evaluators read prompts and answers, which traces carry only with
#   OXYBOT_TRACE_CONTENT=true, so the rules are switched on only when that is set.
# - for the weekly error review: a failure_type score config, an annotation queue that uses it, and a dashboard of
#   how often people correct each AI step per week, split by prompt version and by model
module Langfuse::Setup
  PROVIDER = "oxybot-litellm"

  # What went wrong in an AI output a reviewer looked at; ok when nothing did
  FAILURE_TYPES = %w[wrong_feature missed_need invented_fact wrong_product unclear ok].freeze
  REVIEW_QUEUE = "oxybot-weekly-review"
  DASHBOARD = "OxyBot corrections"
  # The 0/1 scores people's decisions produce (Langfuse::Score), with the AI step each one judges
  DECISIONS = { "feature_match" => "Feature match", "insight_kept" => "Insight kept", "suggestion_accepted" => "Suggestion accepted" }.freeze
  # Scores sit on the model call, which carries its prompt version and model
  SPLITS = { "observationPromptVersion" => "prompt version", "observationModelName" => "model" }.freeze

  EVALUATORS = [
    {
      name: "oxybot-answer-grounded", span: "assistant-turn", model: "oxybot-judge",
      description: "Is every customer claim in an OxyBot answer supported by the quotes it cites?",
      prompt: <<~PROMPT,
        You check an answer written by a product assistant for a product manager.

        Question: {{input}}

        Answer: {{output}}

        Evidence the answer cites, as the assistant's tools returned it: each insight's quote and urgency, and the
        customer record (name, plan, ARR in dollars): {{evidence}}

        Is every statement about customers, their needs, plans, revenue or counts supported by this evidence?
        Totals computed from the evidence are fine. General product context without a customer claim needs no
        evidence. Answer true only if nothing about customers is invented or exaggerated.
      PROMPT
      mapping: [ { variable: "input", source: "input" }, { variable: "output", source: "output" },
                 { variable: "evidence", source: "metadata", jsonPath: "$.evidence" } ]
    },
    {
      name: "oxybot-extraction-faithful", span: "extract-insights", model: "oxybot-judge",
      description: "Do the extracted insights quote the feedback exactly and miss no product need?",
      prompt: <<~PROMPT,
        You check insights a model extracted from customer feedback.

        Feedback: {{input}}

        Extracted insights (JSON): {{output}}

        Answer true only if every quote appears word for word in the feedback, every summary says what the customer
        asked for without adding anything, and no product need in the feedback is missing. Pleasantries are not needs.
      PROMPT
      mapping: [ { variable: "input", source: "input" }, { variable: "output", source: "output" } ]
    }
  ].freeze

  module_function

  def run(log: $stdout)
    connect_litellm.then { |models| log.puts "LLM connection #{PROVIDER}: #{models.size} models through LiteLLM" }
    EVALUATORS.each do |definition|
      evaluator_id = ensure_evaluator(definition)
      enabled = ensure_rule(definition, evaluator_id)
      log.puts "Evaluator #{definition[:name]} on #{definition[:span]} spans: rule #{enabled ? "on" : "off (set OXYBOT_TRACE_CONTENT=true)"}"
    end
    config_id = ensure_failure_type
    log.puts "Score config failure_type (#{FAILURE_TYPES.join(", ")})"
    log.puts ensure_review_queue(config_id)
    log.puts "Dashboard \"#{DASHBOARD}\": #{ensure_dashboard.size} charts"
  end

  def ensure_failure_type
    categories = FAILURE_TYPES.each_with_index.map { |label, value| { label: label, value: value } }
    description = "What went wrong in this AI output, found in the weekly error review"
    existing = Langfuse.get("/api/public/score-configs?limit=100").fetch("data", [])
                       .find { |config| config["name"] == "failure_type" && !config["isArchived"] }
    return Langfuse.post("/api/public/score-configs", { name: "failure_type", dataType: "CATEGORICAL", categories: categories, description: description }).fetch("id") unless existing

    if existing["categories"]&.map { |category| category.slice("label", "value").symbolize_keys } != categories
      Langfuse.request(Net::HTTP::Patch, "/api/public/score-configs/#{existing["id"]}", { categories: categories, description: description })
    end
    existing["id"]
  end

  # Langfuse's API cannot change a queue's score configs, so an existing queue without failure_type is only reported
  def ensure_review_queue(config_id)
    queue = Langfuse.get("/api/public/annotation-queues?limit=100").fetch("data", []).find { |candidate| candidate["name"] == REVIEW_QUEUE }
    unless queue
      Langfuse.post("/api/public/annotation-queues", { name: REVIEW_QUEUE, scoreConfigIds: [ config_id ],
                                                       description: "Weekly review of corrected AI outputs: score each with failure_type" })
      return "Annotation queue #{REVIEW_QUEUE}: created"
    end
    return "Annotation queue #{REVIEW_QUEUE}: ready" if Array(queue["scoreConfigIds"]).include?(config_id)

    "Annotation queue #{REVIEW_QUEUE} exists without failure_type: add it in Langfuse (Annotation queues, edit)"
  end

  # On top, a table per split with the share kept and the number of decisions in the dashboard's date range (a
  # share from three decisions is noise). Below, a weekly line per decision and split: a row per decision, prompt
  # version left and model right. A line is the share of outputs people kept; the correction rate is 1 minus it.
  def ensure_dashboard
    widgets = Langfuse.get("/api/public/unstable/dashboard-widgets?limit=100").fetch("data", [])
    decisions = { column: "name", operator: "any of", type: "stringOptions", value: DECISIONS.keys }
    tables = SPLITS.each_with_index.map do |(field, split), column|
      widget = { name: "Kept share by #{split}", view: "scores-boolean", chartType: "PIVOT_TABLE",
                 description: "Share of decisions that kept the AI output, and how many decisions. Correction rate = 1 - share.",
                 dimensions: [ { field: "name" }, { field: field } ],
                 metrics: [ { measure: "value", agg: "avg" }, { measure: "count", agg: "count" } ], filters: [ decisions ] }
      { type: "widget", id: "oxybot-table-#{field}", widgetId: upsert(widgets, "/api/public/unstable/dashboard-widgets", widget),
        x: column * 6, y: 0, width: 6, height: 5 }
    end
    lines = DECISIONS.each_with_index.flat_map do |(score, label), row|
      SPLITS.each_with_index.map do |(field, split), column|
        widget = { name: "#{label}: kept share by #{split}", view: "scores-boolean", chartType: "LINE_TIME_SERIES",
                   description: "Share of #{score} scores that are 1 (the person kept the AI output). Correction rate = 1 - this.",
                   dimensions: [ { field: field } ], metrics: [ { measure: "value", agg: "avg" } ],
                   filters: [ { column: "name", operator: "=", type: "string", value: score } ] }
        id = upsert(widgets, "/api/public/unstable/dashboard-widgets", widget)
        { type: "widget", id: "oxybot-#{score}-#{field}", widgetId: id, x: column * 6, y: 5 + row * 6, width: 6, height: 6 }
      end
    end
    placements = tables + lines
    dashboards = Langfuse.get("/api/public/unstable/dashboards?limit=100").fetch("data", [])
    dashboard = { name: DASHBOARD, description: "How often people correct each AI step, per week. Lower lines mean more corrections." }
    id = upsert(dashboards, "/api/public/unstable/dashboards", dashboard)
    # The whole layout is replaced on every run, so a rerun never adds tiles twice
    Langfuse.request(Net::HTTP::Patch, "/api/public/unstable/dashboards/#{id}", { definition: { widgets: placements } })
    placements
  end

  # Matched by name: an existing one is updated to the definition here, a missing one created
  def upsert(existing, path, payload)
    found = existing.find { |candidate| candidate["name"] == payload[:name] }
    return Langfuse.post(path, payload).fetch("id") unless found

    Langfuse.request(Net::HTTP::Patch, "#{path}/#{found["id"]}", payload)
    found["id"]
  end

  # Langfuse runs in Docker next to LiteLLM, so it reaches the gateway by its compose service name by default
  def connect_litellm
    models = Account::AiSettings.served_models || Account::AiSettings.available_models
    Langfuse.request(Net::HTTP::Put, "/api/public/llm-connections", {
      provider: PROVIDER, adapter: "openai", secretKey: ENV.fetch("LITELLM_API_KEY", "sk-oxybot-local"),
      baseURL: ENV.fetch("LITELLM_URL_FOR_LANGFUSE", "http://litellm:4000/v1"), customModels: models, withDefaultModels: false
    })
    models
  end

  def ensure_evaluator(definition)
    existing = Langfuse.get("/api/public/v2/evaluators?limit=100").fetch("data", [])
                       .find { |evaluator| evaluator["name"] == definition[:name] }
    return Langfuse.post("/api/public/v2/evaluators", { name: definition[:name], description: definition[:description] }.merge(judge(definition))).fetch("id") unless existing

    # A changed prompt in this file becomes a new evaluator version; rules always use the latest one
    current = Array(existing["prompt"]).map { |message| message.is_a?(Hash) ? message["content"] : message }.join
    Langfuse.request(Net::HTTP::Patch, "/api/public/v2/evaluators/#{existing["id"]}", judge(definition)) if current.strip != definition[:prompt].strip
    existing["id"]
  end

  def judge(definition)
    { type: "llm_as_judge", prompt: definition[:prompt], modelConfig: { provider: PROVIDER, model: definition[:model] },
      variableMapping: definition[:mapping],
      outputDefinition: { dataType: "BOOLEAN", scoreReasoningInstructions: "One or two sentences on what is supported or not.",
                          scoreValueInstructions: "true when the check passes, false otherwise" } }
  end

  # One rule per evaluator, matched by name; it is enabled only when traces carry the content it reads
  def ensure_rule(definition, evaluator_id)
    enabled = Rails.configuration.x.trace_content
    rule = { name: definition[:name], enabled: enabled, sampling: 1,
             # The trace is named after OxyBot's root span, and only that span carries the content the evaluator reads
             filter: [ { type: "stringOptions", column: "traceName", operator: "any of", value: [ definition[:span] ] },
                       { type: "boolean", column: "isRootObservation", operator: "=", value: true } ],
             evaluatorAssignments: [ { evaluatorId: evaluator_id } ] }
    existing = Langfuse.get("/api/public/v2/evaluation-rules").fetch("data", []).find { |candidate| candidate["name"] == definition[:name] }
    if existing
      Langfuse.request(Net::HTTP::Patch, "/api/public/v2/evaluation-rules/#{existing["id"]}", rule.except(:name))
    else
      Langfuse.post("/api/public/v2/evaluation-rules", rule)
    end
    enabled
  end
end
