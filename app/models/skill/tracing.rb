# Shows skills in Langfuse's Skills view. Langfuse links a skill to a trace when spans carry the list of skills the
# agent could use (langfuse.observation.skills_available) and a successful tool call named "loadSkill" asks for one
# by name. OxyBot puts the skill into the prompt rather than loading it through a tool, so the load is recorded as
# its own tool span. Langfuse links usage to a saved skill version, so each skill is registered there first (publish).
# Only skill names and descriptions are sent, never instructions or conversation text.
module Skill::Tracing
  AVAILABLE = Otel::SKILLS_AVAILABLE

  # Every span started inside the block (model calls, tool calls, the load) carries the workspace's skills
  def self.with(available:, used:, &block)
    value = { available: available.map { |skill| { name: skill.langfuse_name, version: skill.langfuse_version }.compact }.to_json,
              used: used&.langfuse_name }
    OpenTelemetry::Context.with_value(Otel::SKILLS, value) do
      loaded(used) if used
      block.call
    end
  end

  def self.loaded(skill)
    attributes = {
      "langfuse.observation.type" => "tool",
      "langfuse.observation.input" => { name: skill.langfuse_name }.to_json,
      "langfuse.observation.output" => { name: skill.langfuse_name, description: skill.description }.to_json
    }
    OpenTelemetry.tracer_provider.tracer("oxybot").in_span("loadSkill", attributes: attributes) { }
  end

  # A new Langfuse version of the skill's card (SKILL.md with name and description); the instructions stay in OxyBot
  def self.publish(skill)
    card = <<~MARKDOWN
      ---
      name: #{skill.langfuse_name}
      description: #{skill.description.squish.to_json}
      ---
      OxyBot skill /#{skill.name}#{" (personal)" unless skill.team?}. Its instructions are kept in OxyBot.
    MARKDOWN
    version = Langfuse.post("/api/public/skills", { files: [ { path: "SKILL.md", content: card } ], commitMessage: "Saved in OxyBot" })["version"]
    skill.update_column(:langfuse_version, version)
  end
end
