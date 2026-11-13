# Creates a new backlog feature from an insight nobody asked for before, and links the insight to it.
class Insights::FeaturesController < ApplicationController
  include InsightScoped

  def create
    feature = @insight.product.features.create!(account: Current.account, title: params[:title].presence || @insight.summary.truncate(120),
                                                 description: @insight.summary)
    @insight.link_to(feature)
    respond_with_triaged "Created #{feature.title}."
  end
end
