require "test_helper"

# With OXYBOT_TRACE_CONTENT=redacted, production traces can carry prompts and answers for debugging, but personal
# data never leaves the app: content goes through Presidio before export, and when Presidio fails it is dropped.
class TraceRedactionTest < ActiveSupport::TestCase
  Span = Struct.new(:name, :attributes)

  class Recorder
    attr_reader :exported

    def export(spans, timeout: nil)
      @exported = spans
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end
  end

  setup do
    @recorder = Recorder.new
    @masked = []
    redactor = ->(text) { @masked << text; text.gsub("Anna Kowalska", "<PERSON>").gsub(/[\w.]+@[\w.]+\.\w+/, "<EMAIL_ADDRESS>") }
    @exporter = Otel::RedactingExporter.new(@recorder, redactor)
  end

  test "content attributes are masked value by value and stay valid JSON; other attributes are untouched" do
    messages = [ { role: "user", content: "Anna Kowalska (anna@northwind.com) needs PDF export" } ].to_json
    span = Span.new("chat", { "gen_ai.input.messages" => messages, "gen_ai.request.model" => "oxybot-haiku",
                              "langfuse.trace.metadata.insight_id" => "12", "langfuse.observation.metadata.evidence" => [ { quote: "Anna Kowalska" } ].to_json })

    @exporter.export([ span ])

    exported = @recorder.exported.first.attributes
    assert_equal [ { "role" => "user", "content" => "<PERSON> (<EMAIL_ADDRESS>) needs PDF export" } ], JSON.parse(exported["gen_ai.input.messages"])
    assert_equal [ { "quote" => "<PERSON>" } ], JSON.parse(exported["langfuse.observation.metadata.evidence"])
    assert_equal [ "oxybot-haiku", "12" ], exported.values_at("gen_ai.request.model", "langfuse.trace.metadata.insight_id")
    assert_includes span.attributes["gen_ai.input.messages"], "Anna Kowalska", "the original span is not changed"
  end

  test "a name right after a JSON quote mark is found, because values are masked one by one" do
    # Like Presidio's NER (measured): "Anna Kowalska is found in plain text, missed when glued to a quote mark
    exporter = Otel::RedactingExporter.new(@recorder, ->(text) { text.gsub(/(?<=\A|\s)Anna Kowalska/, "<PERSON>") })

    exporter.export([ Span.new("chat", { "gen_ai.output.messages" => [ { content: "Anna Kowalska wants PDF" } ].to_json }) ])

    assert_equal "<PERSON> wants PDF", JSON.parse(@recorder.exported.first.attributes["gen_ai.output.messages"]).first["content"]
  end

  test "when the redactor fails, the content is dropped and the span still goes" do
    exporter = Otel::RedactingExporter.new(@recorder, ->(_text) { raise Presidio::Error, "down" })

    exporter.export([ Span.new("chat", { "gen_ai.output.messages" => "Call Anna Kowalska", "gen_ai.usage.input_tokens" => 10 }) ])

    assert_equal [ Otel::RedactingExporter::REMOVED, 10 ], @recorder.exported.first.attributes.values_at("gen_ai.output.messages", "gen_ai.usage.input_tokens")
  end

  test "a text that repeats (the stable part of a prompt) is checked once" do
    system = "You are OxyBot for Acme Analytics."
    2.times { @exporter.export([ Span.new("chat", { "gen_ai.system_instructions" => system }) ]) }

    assert_equal [ system ], @masked
  end

  test "Presidio's two calls: findings from /analyze go to /anonymize" do
    analyze = stub_request(:post, "http://localhost:5012/analyze").to_return(body: [ { entity_type: "PERSON", start: 0, end: 13, score: 0.85 } ].to_json)
    anonymize = stub_request(:post, "http://localhost:5011/anonymize")
                  .with { |request| JSON.parse(request.body)["analyzer_results"].first["entity_type"] == "PERSON" }
                  .to_return(body: { text: "<PERSON> needs PDF" }.to_json)

    assert_equal "<PERSON> needs PDF", Presidio.mask("Anna Kowalska needs PDF")
    assert_requested analyze
    assert_requested anonymize
    stub_request(:post, "http://localhost:5012/analyze").to_return(status: 500)
    assert_raises(Presidio::Error) { Presidio.mask("Anna Kowalska needs PDF") }
  end
end
