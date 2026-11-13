class FeatureDemandTool < ApplicationTool
  description "Ranks backlog features by customer demand: linked insights, distinct customers and their combined ARR."
  parameter :product, description: "Optional product slug", required: false

  def execute(product: nil)
    features = product_scope(account.features, product).includes(:product).by_demand.limit(10).to_a
    samples = sample_insight_ids(features)
    turn.remember_insights(samples.values.flatten)

    { features: features.map { |feature| row(feature, samples.fetch(feature.id, [])) } }
  end

  private

  def row(feature, sample_ids)
    { id: feature.id, title: feature.title, product: feature.product.slug, status: feature.status,
      insight_count: feature.insight_count, customer_count: feature.customer_count,
      arr: arr(feature.demand_arr_cents), sample_insight_ids: sample_ids }.compact
  end

  # Three most recent linked insights per feature, so the answer can cite real evidence
  def sample_insight_ids(features)
    account.insights.where(feature_id: features.map(&:id)).order(id: :desc).pluck(:feature_id, :id)
           .group_by(&:first).transform_values { |pairs| pairs.map(&:last).first(3) }
  end
end
