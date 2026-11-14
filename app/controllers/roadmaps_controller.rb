class RoadmapsController < ApplicationController
  def show
    features = Current.account.features.on_roadmap.includes(:product).by_priority
    @lanes = Feature::LANES.keys.index_with { |lane| features.select { |feature| feature.roadmap_lane == lane } }
    @released = Current.account.features.recently_released.includes(:product).limit(10)
    @candidates = Current.account.features.where(roadmap_lane: nil).where.not(status: "released").by_priority.limit(8)
  end
end
