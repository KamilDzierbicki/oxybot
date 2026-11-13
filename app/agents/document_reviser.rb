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

  model provider: :openai, protocol: :chat_completions, assume_model_exists: true do
    revision.account.ai_model("writer")
  end
  inputs :revision
  instructions do
    document = revision.document
    Prompt.render("document-reviser", document_title: document.title, document_kind: document.kind_name)
  end
  schema SCHEMA
  provider_options { { user: "account-#{revision.account.id}", metadata: revision.trace_metadata } }
end
