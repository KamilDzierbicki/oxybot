# Puts a feature in a roadmap lane, moves it, takes it off the roadmap, or shows or hides it on the customer portal
class Features::RoadmapPlacementsController < ApplicationController
  include FeatureScoped

  def update
    attributes = params.permit(:roadmap_lane, :on_portal)
    lane = attributes[:roadmap_lane]
    @feature.roadmap_lane = lane.presence if attributes.key?(:roadmap_lane)
    @feature.on_portal = ActiveModel::Type::Boolean.new.cast(attributes[:on_portal]) if attributes.key?(:on_portal)
    if @feature.save
      redirect_back_or_to roadmap_path
    else
      redirect_back_or_to roadmap_path, alert: @feature.errors.full_messages.to_sentence
    end
  end
end
