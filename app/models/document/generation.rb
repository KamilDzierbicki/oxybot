# Drafts a document: code gathers the facts for its kind (Document::Brief), the writer model turns them into
# prose following the template, and citations are checked against the insights the brief and tools provided.
class Document::Generation
  include CitationTracking

  attr_reader :document

  delegate :account, to: :document

  def initialize(document)
    @document = document
  end

  def run
    brief = Document::Brief.new(document, self).to_s
    response = DocumentWriter.new(generation: self).ask(brief)
    body, cited = checked_citations(response.content)
    document.transaction do
      document.update!(body: body, status: "ready", cited_insight_ids: cited)
      document.versions.create!(body: body, summary: "Drafted by the agent")
    end
    account.slack_integration&.post_document(document) if document.kind == "opportunity_report"
  rescue RubyLLM::Error, RubyLLM::ToolRoundLimitError, Faraday::Error => e
    Rails.error.report(e, context: { document_id: document.id })
    document.update!(status: "failed", body: "The agent could not draft this document (#{e.class.name.demodulize}). Try again.")
  end

  # Documents are internal, so revenue may appear in them
  def revenue_visible? = true
  def user = document.creator

  def trace_metadata
    { trace_id: "document-#{document.id}", generation_name: "write-#{document.kind}",
      tags: [ "account-#{account.id}", "document-#{document.kind}" ] }
  end
end
