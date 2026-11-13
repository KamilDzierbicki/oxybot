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
    Prompt.render("document-reviser", document_title: document.title, document_kind: document.kind_name, document_body: document.body)
  end
  schema SCHEMA
  end_user { "account-#{revision.account.id}" }
  provider_options { { metadata: revision.trace_metadata } }
end
