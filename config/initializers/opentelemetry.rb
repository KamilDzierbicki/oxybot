# Sends RubyLLM's spans (model, tokens, tool names; no prompt text) to Langfuse's OTLP endpoint.
# The Faraday instrumentation adds a traceparent header to each model call, so LiteLLM's own spans
# become children of the app's span and one assistant turn is one trace.
require "opentelemetry/sdk"
require Rails.root.join("lib/otel/skill_span_processor") # needed in every environment: Skill::Tracing uses its key
require Rails.root.join("lib/otel/baggage_span_processor")
require Rails.root.join("lib/otel/prompt_span_processor")
require Rails.root.join("lib/otel/generation_span_processor") # needed in every environment: Langfuse.traced uses its key
require Rails.root.join("lib/otel/environment")
require Rails.root.join("lib/otel/redacting_exporter")
require Rails.root.join("lib/presidio")

return if Rails.env.test? || ENV["LANGFUSE_URL"].blank?

require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/faraday"

OpenTelemetry::SDK.configure do |config|
  config.service_name = "oxybot-rails"
  # Langfuse keeps development, staging and production traces apart by this environment
  config.resource = OpenTelemetry::SDK::Resources::Resource.create("deployment.environment.name" => Otel.environment)
  config.add_span_processor(Otel::SkillSpanProcessor.new) # skill names for Langfuse's Skills view
  config.add_span_processor(Otel::BaggageSpanProcessor.new) # experiment context for Langfuse
  config.add_span_processor(Otel::PromptSpanProcessor.new) # prompt version per model call
  config.add_span_processor(Otel::GenerationSpanProcessor.new) # the model call a person's decision is scored on
  exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
    endpoint: "#{ENV.fetch("LANGFUSE_URL")}/api/public/otel/v1/traces",
    headers: { "Authorization" => "Basic #{Base64.strict_encode64("#{ENV.fetch("LANGFUSE_PUBLIC_KEY")}:#{ENV.fetch("LANGFUSE_SECRET_KEY")}")}",
               "x-langfuse-ingestion-version" => "4" }
  )
  # OXYBOT_TRACE_CONTENT=redacted: personal data leaves prompts and answers before they leave the app
  exporter = Otel::RedactingExporter.new(exporter, Presidio.method(:mask), logger: Rails.logger) if Rails.configuration.x.trace_redacted
  config.add_span_processor(OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter))
  config.use "OpenTelemetry::Instrumentation::Faraday"
end
# Prompts and answers stay out of traces unless OXYBOT_TRACE_CONTENT is set on purpose: they hold customer feedback.
# "redacted" is for production (personal data removed by Presidio); "true" only where raw text is fine (local work,
# a demo workspace). Either lets Langfuse evaluators read them.
RubyLLM::OpenTelemetry.enable(content: Rails.configuration.x.trace_content)
# Spans leave in batches; flush the last one when a process ends, or the end of a run never arrives.
at_exit { OpenTelemetry.tracer_provider.shutdown if OpenTelemetry.tracer_provider.respond_to?(:shutdown) }
