# Everything the workspace holds, as one JSON file (data portability). Secrets and password hashes are left out.
class Workspaces::ExportsController < ApplicationController
  admin_only
  rate_limit to: 5, within: 1.hour, by: -> { Current.account.id }, with: -> { redirect_to workspace_path, alert: "Try again later." }

  def show
    send_data Current.account.export.to_json, filename: "oxybot-#{Current.account.name.parameterize}-#{Date.current}.json", type: :json
  end
end
