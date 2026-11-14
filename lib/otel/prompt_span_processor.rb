# Links each model call to the Langfuse prompt version it was built from (langfuse.observation.prompt.*), so the
# prompt page in Langfuse shows cost, latency and scores per version. Set around an agent call by Prompt.linked.
module Otel
  PROMPT = OpenTelemetry::Context.create_key("oxybot.prompt")

  class PromptSpanProcessor
    def on_start(span, parent_context)
      prompt = parent_context.value(PROMPT)
      return unless prompt && span.attributes&.dig("gen_ai.operation.name") == "chat"

      span.set_attribute("langfuse.observation.prompt.name", prompt[:name])
      span.set_attribute("langfuse.observation.prompt.version", prompt[:version])
    end

    def on_finish(span) = nil
    def force_flush(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
    def shutdown(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end
