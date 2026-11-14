class Portal::RoadmapsController < Portal::BaseController
  def show
    features = portal.features.where(on_portal: true).includes(:product)
    @votes = PortalVote.where(feature: features).group(:feature_id).count
    @lanes = Feature::LANES.keys.index_with { |lane| features.select { |feature| feature.roadmap_lane == lane }.sort_by { |feature| [ -@votes.fetch(feature.id, 0), feature.title ] } }
    @released = features.recently_released.limit(10)
  end
end
