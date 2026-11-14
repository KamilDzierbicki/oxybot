module Otel
  # Lowercase name Langfuse files traces and scores under, so development traces never mix with production.
  # Here rather than in app/ because the OpenTelemetry initializer needs it at boot.
  def self.environment = ENV.fetch("LANGFUSE_ENVIRONMENT", Rails.env).downcase.gsub(/[^a-z0-9_-]/, "-")
end
