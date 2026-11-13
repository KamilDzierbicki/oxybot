class InsightExtractor < RubyLLM::Agent
  SCHEMA = {
    type: "object",
    properties: {
      insights: {
        type: "array",
        items: {
          type: "object",
          properties: {
            product_slug: { type: "string" },
            quote: { type: "string", description: "The customer's own words, copied exactly" },
            summary: { type: "string", description: "The need in one neutral sentence" },
            urgency: { type: "string", enum: %w[low medium high] },
            customer_name: { type: [ "string", "null" ], description: "Customer company if the text names it" }
          },
          required: %w[product_slug quote summary urgency customer_name],
          additionalProperties: false
        }
      }
    },
    required: %w[insights],
    additionalProperties: false
  }.freeze

  model provider: :openai, protocol: :chat_completions, assume_model_exists: true do
    note.account.ai_model("extract")
  end
  max_output_tokens 2000
  inputs :note
  instructions { Prompt.render("insight-extractor", products: Prompt::Context.new(note.account).products) }
  schema SCHEMA
  provider_options do
    { user: "account-#{note.account_id}", metadata: { trace_name: "extract-insights", generation_name: "extract-insights", trace_id: "feedback-note-#{note.id}",
                  tags: [ "account-#{note.account_id}", Prompt.version_tag("insight-extractor") ] } }
  end
end
