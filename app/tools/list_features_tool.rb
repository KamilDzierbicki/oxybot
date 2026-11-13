class ListFeaturesTool < ApplicationTool
  description "Lists backlog features with their status and description."
  parameter :product, description: "Optional product slug", required: false
  parameter :status, description: "Optional status: idea, planned, in_progress or released", required: false

  def execute(product: nil, status: nil)
    features = product_scope(account.features, product).includes(:product).order(:title)
    features = features.where(status: status) if Feature::STATUSES.include?(status)

    { features: features.limit(30).map { |feature| { id: feature.id, title: feature.title, product: feature.product.slug,
                                                     status: feature.status, description: feature.description.truncate(200) } } }
  end
end
