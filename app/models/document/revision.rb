# Turns a person's request ("shorten the problem section") into a suggested new body for the document.
class Document::Revision
  include CitationTracking

  attr_reader :suggestion

  delegate :document, to: :suggestion
  delegate :account, to: :document

  def initialize(suggestion)
    @suggestion = suggestion
  end

  def run
    remember_insights(document.cited_insight_ids)
    reply = DocumentReviser.new(revision: self).ask("Request: #{suggestion.instruction}").parsed || {}
    body, _cited = checked_citations(reply["body"])
    raise RubyLLM::Error, "empty revision" if body.blank?

    suggestion.update!(body: body, rationale: reply["rationale"].to_s.truncate(1_000), status: "pending")
    suggestion.accept(user: suggestion.user) if document.auto_accept? && !suggestion.stale?
  rescue RubyLLM::Error, Faraday::Error => e
    Rails.error.report(e, context: { suggestion_id: suggestion.id })
    suggestion.update!(status: "failed", rationale: "The agent could not revise the document (#{e.class.name.demodulize}).")
  end

  def revenue_visible? = true

  def trace_metadata
    { trace_id: "document-#{document.id}", generation_name: "revise-#{document.kind}", tags: [ "account-#{account.id}", Prompt.version_tag("document-reviser") ] }
  end
end
