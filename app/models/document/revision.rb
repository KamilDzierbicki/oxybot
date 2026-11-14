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
    Langfuse.traced("revise-document", account: account, document_id: document.id, suggestion_id: suggestion.id,
                                        oxybot_url: Langfuse.url(document, anchor: "document_suggestion_#{suggestion.id}")) do |trace|
      remember_insights(document.cited_insight_ids)
      reply = Prompt.linked("document-reviser") do
        DocumentReviser.new(revision: self).ask("<document>\n#{base_body}\n</document>\n\nRequest: #{suggestion.instruction}")
      end.parsed || {}
      body, _cited = checked_citations(clean(reply["body"]))
      if body.blank? || body.squish == base_body.squish
        next suggestion.update!(status: "failed", rationale: "The agent returned the document unchanged. Try a more specific request.", trace_id: trace.id,
                                  observation_id: trace.generation_id)
      end

      suggestion.update!(body: body, rationale: reply["rationale"].to_s.truncate(1_000), status: "pending", trace_id: trace.id,
                         observation_id: trace.generation_id)
      suggestion.accept(user: suggestion.user) if document.auto_accept? && !suggestion.stale?
    end
  rescue RubyLLM::Error, Faraday::Error => e
    Rails.error.report(e, context: { suggestion_id: suggestion.id })
    suggestion.update!(status: "failed", rationale: LiteLlm.budget_exceeded?(e) ? LiteLlm::BUDGET_MESSAGE : "The agent could not revise the document (#{e.class.name.demodulize}).")
  end

  def revenue_visible? = true

  def trace_metadata
    { trace_id: "document-#{document.id}", generation_name: "revise-#{document.kind}", tags: [ "account-#{account.id}", Prompt.version_tag("document-reviser") ] }
  end

  private

  def base_body
    suggestion.base_version&.body || document.body
  end

  # Models sometimes echo the framing around the document, or put its title on top as a heading; neither is part
  # of the document unless the document already started that way
  def clean(text)
    text = text.to_s.gsub(%r{</?document>}, "").sub(/\A\s*(Current version|Request):.*\n/, "").strip
    first_line = text.lines.first.to_s
    if first_line.start_with?("# ") && first_line.include?(document.title) && !base_body.lstrip.start_with?(first_line.strip)
      text = text.lines.drop(1).join.lstrip
    end
    text
  end
end
