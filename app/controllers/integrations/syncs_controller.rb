class Integrations::SyncsController < ApplicationController
  admin_only

  def create
    integration = Current.account.integrations.where(type: "Integration::Hubspot").find(params[:integration_id])
    integration.sync_later
    redirect_to integration, notice: "Sync started. Customers update in a few seconds."
  end
end
