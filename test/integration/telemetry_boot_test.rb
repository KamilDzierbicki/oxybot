require "test_helper"
require "open3"

# The OpenTelemetry initializer is skipped in tests, so a mistake in it (such as naming an autoloaded class during
# boot) would silently switch tracing off everywhere else. This boots the app the way a server does.
class TelemetryBootTest < ActiveSupport::TestCase
  test "with Langfuse configured the app boots with a real tracer provider and the skill span processor" do
    env = { "RAILS_ENV" => "development", "LANGFUSE_URL" => "http://127.0.0.1:9", "LANGFUSE_PUBLIC_KEY" => "pk",
            "LANGFUSE_SECRET_KEY" => "sk", "OTEL_LOG_LEVEL" => "error" }
    script = "p = OpenTelemetry.tracer_provider; puts p.class.name; " \
             'puts p.instance_variable_get(:@span_processors).map { |sp| sp.class.name }.join(","); ' \
             'puts p.resource.attribute_enumerator.to_h["deployment.environment.name"]'
    output, status = Open3.capture2e(env, "bin/rails", "runner", script, chdir: Rails.root.to_s)

    assert status.success?, output
    assert_not_includes output, "OpenTelemetry error", output
    assert_includes output, "OpenTelemetry::SDK::Trace::TracerProvider"
    assert_includes output, "Otel::SkillSpanProcessor"
    assert_includes output, "Otel::PromptSpanProcessor"
    assert_includes output.lines.map(&:strip), "development", "traces carry their environment"
  end
end
