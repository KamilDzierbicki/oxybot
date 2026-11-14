# Pulls new data from an integration that syncs: CRM companies and contacts (HubSpot, Salesforce) or feedback
# conversations (Intercom, Zendesk, Gong). Without an argument, the hourly run (config/recurring.yml) syncs them all.
class SyncIntegrationJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(integration = nil) { integration&.id || "all" }
  retry_on Integration::Http::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 3

  def perform(integration = nil)
    if integration
      integration.sync
    else
      Integration.find_each { |each_integration| each_integration.sync_later if each_integration.syncs? }
    end
  end
end
