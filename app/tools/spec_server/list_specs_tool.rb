class SpecServer::ListSpecsTool < SpecServer::BaseTool
  tool_name "list_specs"
  description "Lists the product specs (PRDs) of your OxyBot workspace, newest first, with their feature and Linear issue."
  input_schema(properties: { query: { type: "string", description: "Optional words to filter titles by" } })

  def self.call(server_context:, query: nil)
    specs = account(server_context).documents.specs.ready.includes(:feature).latest_first.limit(50)
    specs = specs.where("documents.title ILIKE ?", "%#{Document.sanitize_sql_like(query)}%") if query.present?
    text(specs.map { |spec| { id: spec.id, title: spec.title, feature: spec.feature&.title, feature_status: spec.feature&.status,
                              linear_issue: spec.feature&.linear_identifier, updated_at: spec.updated_at.iso8601 } })
  end
end
