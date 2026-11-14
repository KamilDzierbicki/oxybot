# Langfuse reads experiment context (langfuse.experiment.*, langfuse.environment) from span attributes. Its SDKs carry
# that context as OpenTelemetry Baggage and copy it onto every span; this processor does the same for OxyBot.
module Otel
  class BaggageSpanProcessor
    def on_start(span, parent_context)
      OpenTelemetry::Baggage.values(context: parent_context).each do |key, value|
        span.set_attribute(key, value) if key.start_with?("langfuse.")
      end
    end

    def on_finish(span) = nil
    def force_flush(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
    def shutdown(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end
