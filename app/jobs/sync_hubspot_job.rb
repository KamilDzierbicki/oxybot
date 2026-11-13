class SyncHubspotJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(integration) { integration.id }

  # Without an integration: the recurring run (config/recurring.yml) syncs every account
  def perform(integration = nil)
    if integration
      integration.sync
    else
      Integration::Hubspot.find_each(&:sync_later)
    end
  end
end
