class InsightsController < ApplicationController
  include Paginated
  STATES = Insight::TRIAGE_STATES

  def index
    @state = STATES.include?(params[:state]) ? params[:state] : "pending"
    @insights = paginate(Current.account.insights.where(triage_state: @state)
                       .includes(:product, :customer, :feature, :suggested_feature, :feedback_note).latest_first)
    @features_by_product = Current.account.features.order(:title).group_by(&:product_id)
  end

  def show
    @insight = Current.account.insights.find(params[:id])
    @features = @insight.product.features.order(:title)
  end
end
