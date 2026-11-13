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
            customer_name: { type: ["string", "null"], description: "Customer company if the text names it" }
          },
          required: %w[product_slug quote summary urgency customer_name],
          additionalProperties: false
        }
      }
    },
    required: %w[insights],
    additionalProperties: false
  }.freeze

  model "flint-extract", provider: :openai, protocol: :chat_completions, assume_model_exists: true
  inputs :note
  instructions { RubyLLM.render_prompt("insight_extractor/instructions", products: note.account.products.alphabetically) }
  schema SCHEMA
  end_user { "account-#{note.account_id}" }
  provider_options { { metadata: { trace_name: "extract-insights", trace_id: "feedback-note-#{note.id}", tags: ["account-#{note.account_id}"] } } }
end
