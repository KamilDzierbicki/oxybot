class Integrations::ConnectionChecksController < ApplicationController
  admin_only

  def create
    integration = Current.account.integrations.find(params[:integration_id])
    ok, message = integration.check_connection
    redirect_to integration, (ok ? :notice : :alert) => message
  end
end
