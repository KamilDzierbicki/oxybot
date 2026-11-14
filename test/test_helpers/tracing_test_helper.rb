# Real OpenTelemetry spans in memory, and Langfuse "configured" against a stubbed host.
# OpenTelemetry accepts a global tracer provider once per process, so tests share one and reset its exporter.
module TracingTestHelper
  EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  PROVIDER = OpenTelemetry::SDK::Trace::TracerProvider.new.tap do |provider|
    provider.add_span_processor(Otel::SkillSpanProcessor.new)
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER))
  end
  LANGFUSE = { "LANGFUSE_URL" => "http://langfuse.test", "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk" }.freeze

  def start_tracing
    OpenTelemetry.tracer_provider = PROVIDER unless OpenTelemetry.tracer_provider == PROVIDER
    EXPORTER.reset
    RubyLLM::OpenTelemetry.enable
  end

  def stop_tracing = RubyLLM::OpenTelemetry.disable

  def finished_spans = EXPORTER.finished_spans

  def with_langfuse
    previous = LANGFUSE.keys.to_h { |key| [ key, ENV[key] ] }
    ENV.update(LANGFUSE)
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
