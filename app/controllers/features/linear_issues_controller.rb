class Features::LinearIssuesController < ApplicationController
  include FeatureScoped

  def create
    return redirect_to(@feature, alert: "Connect Linear on the Integrations page first.") unless Current.account.linear_integration

    @feature.send_to_linear
    redirect_to @feature, notice: "Created #{@feature.linear_identifier} in Linear."
  rescue ArgumentError, Integration::Linear::Client::Error => e
    redirect_to @feature, alert: e.message
  end
end
