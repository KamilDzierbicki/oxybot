# Integration access tokens (Slack bot token, HubSpot private app token) are encrypted at rest.
# Production reads the three keys from environment variables (generate them with bin/rails db:encryption:init);
# development and test get fixed local keys so the app starts with no setup.
Rails.application.config.active_record.encryption.tap do |encryption|
  if Rails.env.production?
    encryption.primary_key ||= ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    encryption.deterministic_key ||= ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    encryption.key_derivation_salt ||= ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
  else
    encryption.primary_key ||= "oxybot-local-primary-key-not-for-production"
    encryption.deterministic_key ||= "oxybot-local-deterministic-key-not-for-production"
    encryption.key_derivation_salt ||= "oxybot-local-key-derivation-salt"
  end
end
