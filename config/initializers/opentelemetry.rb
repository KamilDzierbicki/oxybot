# Sends RubyLLM's spans (model, tokens, tool names; no prompt text) to Langfuse's OTLP endpoint.
# The Faraday instrumentation adds a traceparent header to each model call, so LiteLLM's own spans
# become children of the app's span and one assistant turn is one trace.
return if Rails.env.test? || ENV["LANGFUSE_URL"].blank?

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/faraday"

OpenTelemetry::SDK.configure do |config|
  config.service_name = "oxybot-rails"
  config.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: "#{ENV.fetch("LANGFUSE_URL")}/api/public/otel/v1/traces",
        headers: { "Authorization" => "Basic #{Base64.strict_encode64("#{ENV.fetch("LANGFUSE_PUBLIC_KEY")}:#{ENV.fetch("LANGFUSE_SECRET_KEY")}")}",
                   "x-langfuse-ingestion-version" => "4" }
      )
    )
  )
  config.use "OpenTelemetry::Instrumentation::Faraday"
end
RubyLLM::OpenTelemetry.enable
# Spans leave in batches; flush the last one when a process ends, or the end of a run never arrives.
at_exit { OpenTelemetry.tracer_provider.shutdown }
