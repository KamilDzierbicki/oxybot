class DocumentReviser < RubyLLM::Agent
  SCHEMA = {
    type: "object",
    properties: {
      body: { type: "string", description: "The whole revised document in Markdown" },
      rationale: { type: "string", description: "One or two sentences on what changed and why" }
    },
    required: %w[body rationale],
    additionalProperties: false
  }.freeze

  model "oxybot-writer", provider: :openai, protocol: :chat_completions, assume_model_exists: true
  inputs :revision
  instructions { RubyLLM.render_prompt("document_reviser/instructions", document: revision.document) }
  schema SCHEMA
  end_user { "account-#{revision.account.id}" }
  provider_options { { metadata: revision.trace_metadata } }
end
