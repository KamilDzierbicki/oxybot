class Portal::VotesController < Portal::BaseController
  rate_limit to: 60, within: 1.hour, by: -> { "#{portal.id}:#{current_visitor&.id || request.remote_ip}" },
             with: -> { redirect_back_or_to portal_root_path(portal_slug: params[:portal_slug]), alert: "Too many votes in an hour. Try again later." }
  before_action :require_visitor
  before_action :set_feature

  def create
    PortalVote.cast(current_visitor, @feature) unless current_visitor.voted_for?(@feature)
    redirect_back_or_to portal_root
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    redirect_back_or_to portal_root
  end

  def destroy
    current_visitor.portal_votes.find_by(feature: @feature)&.destroy
    redirect_back_or_to portal_root
  end

  private

  # Only features shown on this portal can be voted for
  def set_feature
    @feature = portal.features.where(on_portal: true).find(params[:feature_id])
  end
end
