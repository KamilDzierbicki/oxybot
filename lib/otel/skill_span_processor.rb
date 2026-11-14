# Copies the skills of the current agent turn onto every span started in it (see Skill::Tracing).
# Lives outside app/ so the tracer provider, built once at boot, never holds a class that code reloading replaced.
module Otel
  SKILLS = OpenTelemetry::Context.create_key("oxybot.skills")
  SKILLS_AVAILABLE = "langfuse.observation.skills_available"

  class SkillSpanProcessor
    def on_start(span, parent_context)
      skills = parent_context.value(SKILLS)
      return unless skills

      span.set_attribute(SKILLS_AVAILABLE, skills[:available])
      span.set_attribute("langfuse.trace.metadata.skill", skills[:used]) if skills[:used]
    end

    def on_finish(span) = nil
    def force_flush(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
    def shutdown(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end
