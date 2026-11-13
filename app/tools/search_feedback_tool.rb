class SearchFeedbackTool < ApplicationTool
  description "Searches customer feedback insights by meaning and keywords. Returns quotes, customers and linked features."
  parameter :query, description: "What to look for, in a few words"
  parameter :product, description: "Optional product slug to search within", required: false

  def execute(query:, product: nil)
    insights = product_scope(account.insights, product).where.not(triage_state: "dismissed")
                                                     .includes(:customer, :product, :feature).hybrid_search(query, limit: 10)
    turn.remember_insights(insights.map(&:id))

    { insights: insights.map { |insight| row(insight) } }
  end

  private

  def row(insight)
    { id: insight.id, summary: insight.summary, quote: insight.quote, urgency: insight.urgency,
      product: insight.product.slug, customer: insight.customer&.name, plan: insight.customer&.plan, arr: insight.customer && arr(insight.customer.arr_cents),
      feature: insight.feature&.title, date: insight.created_at.to_date.iso8601 }.compact
  end
end
