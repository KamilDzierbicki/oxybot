class SpecServer::SearchFeedbackTool < SpecServer::BaseTool
  tool_name "search_feedback"
  description "Searches customer feedback insights in your OpenSpark workspace by meaning and keywords."
  input_schema(properties: { query: { type: "string" } }, required: [ "query" ])

  def self.call(query:, server_context:)
    insights = account(server_context).insights.where.not(triage_state: "dismissed").includes(:customer, :feature).hybrid_search(query, limit: 10)
    text(insights.map { |insight| { id: insight.id, summary: insight.summary, quote: insight.quote, customer: insight.customer&.name, feature: insight.feature&.title } })
  end
end
