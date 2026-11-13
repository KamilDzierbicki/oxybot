class SpecServer::GetSpecTool < SpecServer::BaseTool
  tool_name "get_spec"
  description "Returns one product spec in Markdown, followed by the customer evidence it cites. Use it before implementing the feature."
  input_schema(properties: { id: { type: "integer", description: "Spec id from list_specs" } }, required: [ "id" ])

  def self.call(id:, server_context:)
    spec = account(server_context).documents.specs.find_by(id: id)
    return text("No spec with id #{id} in this workspace.") unless spec

    evidence = spec.account.insights.where(id: spec.cited_insight_ids).includes(:customer).map do |insight|
      "- [insight:#{insight.id}] #{insight.summary} (#{insight.customer&.name || "unknown customer"}): \"#{insight.quote.squish}\""
    end
    text([ spec.body, ("## Cited customer evidence\n#{evidence.join("\n")}" if evidence.any?) ].compact.join("\n\n"))
  end
end
