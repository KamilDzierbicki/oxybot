# Mock mode only: moves the feature's Linear issue as if someone did it in Linear, through the webhook path
class Features::LinearSimulationsController < ApplicationController
  include FeatureScoped

  def create
    linear = Current.account.linear_integration
    return head :not_found unless linear&.mock? && @feature.in_linear?

    state_type = params.expect(:state_type)
    return head :unprocessable_entity unless Integration::Linear::STATUS_BY_STATE_TYPE.key?(state_type)

    linear.simulate_state_change(@feature, state_type)
    redirect_to @feature, notice: "Linear moved #{@feature.linear_identifier} to #{state_type.humanize}; the feature followed."
  end
end
