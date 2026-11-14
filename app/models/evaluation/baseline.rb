# The stored minimums of config/evals/baseline.yml, and the check of a run against them: every listed score must
# reach its minimum, and a score missing from the run fails too, so a renamed score cannot pass silently.
class Evaluation::Baseline
  FILE = Rails.root.join("config/evals/baseline.yml")

  Row = Data.define(:task, :score, :minimum, :value) do
    def passed? = !value.nil? && value >= minimum
  end

  attr_reader :model, :tasks

  def initialize(definition = YAML.load_file(FILE))
    @model = definition.fetch("model")
    @tasks = definition.fetch("tasks")
  end

  # The baseline file with the minimums replaced by these averages, rounded down to two decimals, for
  # bin/rails evals:baseline. Rewritten whole, so review the diff before committing it.
  def self.text(model, averages)
    tasks = averages.map do |task, scores|
      "  #{task}: { #{scores.map { |score, value| "#{score}: #{(value * 100).floor / 100.0}" }.join(", ")} }"
    end
    <<~YAML
      # The minimum average a change must keep, per evaluation task and score (bin/rails evals:check, run by the CI
      # Evals workflow when prompts, agents, tools or retrieval change). Written by bin/rails evals:baseline from a
      # measured run; review the diff and commit it on purpose, never to make a failing change pass. See docs/EVALS.md.
      model: #{model}
      tasks:
      #{tasks.join("\n")}
    YAML
  end

  # averages: task => Evaluation.averages of its run
  def compare(averages)
    tasks.flat_map do |task, minimums|
      minimums.map { |score, minimum| Row.new(task: task, score: score, minimum: minimum, value: averages.dig(task, score)) }
    end
  end
end
