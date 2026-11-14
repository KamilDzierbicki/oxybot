# Configures the Langfuse project to work with OxyBot and LiteLLM (bin/rails langfuse:setup, safe to run again):
#
# - an LLM connection to the LiteLLM gateway, so Langfuse's evaluators and playground use the same model aliases,
#   budgets and cost tracking as the app
# - two LLM-as-judge evaluators on OxyBot's own root spans: is an assistant answer supported by the quotes it cites,
#   and do extracted insights stay true to the feedback
# - rules that run them on new traces. Evaluators read prompts and answers, which traces carry only with
#   OXYBOT_TRACE_CONTENT=true, so the rules are switched on only when that is set.
module Langfuse::Setup
  PROVIDER = "oxybot-litellm"

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
