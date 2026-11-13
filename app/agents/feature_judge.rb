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

  model provider: :openai, protocol: :chat_completions, assume_model_exists: true do
    insight.account.ai_model("judge")
  end
  inputs :insight, :candidates
  instructions do
    Prompt.render("feature-judge", insight_summary: insight.summary.squish, insight_quote: insight.quote.squish,
                                   candidates: candidates.map { |feature| "- [#{feature.id}] #{feature.title.squish}: #{feature.description.squish}" }.join("\n"))
  end
  schema SCHEMA
  provider_options do
    { user: "account-#{insight.account_id}", metadata: { trace_name: "match-feature", generation_name: "match-feature", trace_id: "insight-#{insight.id}",
                  tags: [ "account-#{insight.account_id}", Prompt.version_tag("feature-judge") ] } }
  end
end
