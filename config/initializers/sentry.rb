# Error monitoring with Sentry or a self-hosted GlitchTip (same SDK, set SENTRY_DSN). It also receives
# Rails.error reports, so failed model calls and failed jobs are no longer silent.
return if ENV["SENTRY_DSN"].blank?

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = Rails.env
  config.breadcrumbs_logger = [ :active_support_logger ]
  config.send_default_pii = false # no request bodies: they hold customer feedback
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0").to_f
end
