# Integration access tokens (Slack bot token, HubSpot private app token) are encrypted at rest.
# Production reads the keys from credentials (bin/rails db:encryption:init); development and test
# get fixed local keys so the app starts without credentials.
unless Rails.env.production?
  Rails.application.config.active_record.encryption.tap do |encryption|
    encryption.primary_key ||= "openspark-local-primary-key-not-for-production"
    encryption.deterministic_key ||= "openspark-local-deterministic-key-not-for-production"
    encryption.key_derivation_salt ||= "openspark-local-key-derivation-salt"
  end
end
