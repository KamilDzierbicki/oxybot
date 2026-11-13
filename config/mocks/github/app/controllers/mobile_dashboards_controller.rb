# JSON API for the iOS and Android apps. Every request needs a network connection; there is no offline cache
# yet, the apps only keep the last response in memory.
class MobileDashboardsController < Api::BaseController
  def show
    dashboard = current_account.dashboards.find(params[:id])
    render json: DashboardSerializer.new(dashboard, include_series: true)
  end
end
