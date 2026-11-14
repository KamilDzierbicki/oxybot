class Integrations::SyncsController < ApplicationController
  admin_only

  def create
    integration = Current.account.integrations.find(params[:integration_id])
    return head :not_found unless integration.syncs?

    integration.sync_later
    redirect_to integration, notice: "Syncing… this page updates when it is done."
  end
end
