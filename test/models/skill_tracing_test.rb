require "test_helper"

class SkillTracingTest < ActiveSupport::TestCase
  # OpenTelemetry accepts a global tracer provider once per process, so the tests share one and reset its exporter
  EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  PROVIDER = OpenTelemetry::SDK::Trace::TracerProvider.new.tap do |provider|
    provider.add_span_processor(Otel::SkillSpanProcessor.new)
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER))
  end

  setup do
    OpenTelemetry.tracer_provider = PROVIDER unless OpenTelemetry.tracer_provider == PROVIDER
    EXPORTER.reset
    RubyLLM::OpenTelemetry.enable
    @exporter = EXPORTER
  end

  teardown { RubyLLM::OpenTelemetry.disable }

  test "a skill run in a chat shows in Langfuse as loaded, and model spans list only this workspace's skills" do
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))
    conversation.ask("/voc")
    perform_enqueued_jobs(only: GenerateReplyJob)

    spans = @exporter.finished_spans
    load = spans.find { |span| span.name == "loadSkill" }
    assert load, "Langfuse counts a skill as used only through a tool call named loadSkill"
    assert_equal "tool", load.attributes["langfuse.observation.type"]
    personal = skills(:kamil_voc) # a personal skill wins over the team skill of the same name
    assert_equal "a#{accounts(:acme).id}-u#{users(:kamil).id}-voc", JSON.parse(load.attributes["langfuse.observation.input"])["name"]

    model_spans = spans.select { |span| span.attributes["gen_ai.operation.name"] == "chat" }
    assert model_spans.any?
    available = JSON.parse(model_spans.first.attributes[Skill::Tracing::AVAILABLE]).map { |skill| skill["name"] }
    assert_includes available, personal.langfuse_name
    assert_includes available, skills(:team_voc).langfuse_name
    assert_not_includes available, skills(:globex_secret).langfuse_name, "another workspace's skill never appears"
    assert_equal accounts(:acme).skills.where(user: [ nil, users(:kamil) ]).count, available.size
  end

  test "a turn without a skill records no load" do
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))
    conversation.ask("What do customers say about PDF export?")
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_not @exporter.finished_spans.any? { |span| span.name == "loadSkill" }
  end

  test "registering a skill in Langfuse sends its name and description, never its instructions, and keeps the version" do
    skill = skills(:team_voc)
    request = stub_request(:post, "http://langfuse.test/api/public/skills").to_return(body: { version: 3 }.to_json)

    with_langfuse { Skill::Tracing.publish(skill) }

    assert_requested request
    card = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)["files"].first["content"]
    assert_includes card, "name: #{skill.langfuse_name}"
    assert_not_includes card, skill.instructions
    assert_equal 3, skill.reload.langfuse_version
  end

  test "a model span names the registered version, so Langfuse can link the use to it" do
    skills(:team_voc).update_column(:langfuse_version, 7)
    Skill::Tracing.with(available: [ skills(:team_voc).reload ], used: nil) do
      OpenTelemetry.tracer_provider.tracer("test").in_span("chat") { }
    end

    assert_equal [ { "name" => skills(:team_voc).langfuse_name, "version" => 7 } ],
                 JSON.parse(@exporter.finished_spans.last.attributes[Skill::Tracing::AVAILABLE])
  end

  private

  def with_langfuse
    keys = { "LANGFUSE_URL" => "http://langfuse.test", "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk" }
    previous = keys.keys.to_h { |key| [ key, ENV[key] ] }
    ENV.update(keys)
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
