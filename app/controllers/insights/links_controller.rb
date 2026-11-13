class Insights::LinksController < ApplicationController
  include InsightScoped

  def create
    feature = @insight.product.features.find(params.expect(:feature_id))
    @insight.link_to(feature)
    respond_with_triaged "Linked to #{feature.title}."
  end
end
