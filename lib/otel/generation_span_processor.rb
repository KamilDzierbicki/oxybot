# Remembers the last model call under an OxyBot root span (Langfuse.traced). A person's decision is scored on that
# call, so Langfuse can split the scores by the prompt version and model the call carries.
module Otel
  TRACE = OpenTelemetry::Context.create_key("oxybot.trace")

  class GenerationSpanProcessor
    def on_start(span, parent_context)
      trace = parent_context.value(TRACE)
      trace.generation_id = span.context.hex_span_id if trace && span.attributes&.dig("gen_ai.operation.name") == "chat"
    end

    def on_finish(span) = nil
    def force_flush(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
    def shutdown(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end
