class FeatureJudge < RubyLLM::Agent
  SCHEMA = {
    type: "object",
    properties: {
      feature_id: { type: [ "integer", "null" ], description: "Id of the matching candidate, or null" },
      confidence: { type: "number" },
      reason: { type: "string" }
    },
    required: %w[feature_id confidence reason],
    additionalProperties: false
  }.freeze

  model "oxybot-judge", provider: :openai, protocol: :chat_completions, assume_model_exists: true
  inputs :insight, :candidates
  instructions { RubyLLM.render_prompt("feature_judge/instructions", insight: insight, candidates: candidates) }
  schema SCHEMA
  end_user { "account-#{insight.account_id}" }
  provider_options { { metadata: { trace_name: "match-feature", trace_id: "insight-#{insight.id}", tags: [ "account-#{insight.account_id}" ] } } }
end
