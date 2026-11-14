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

  # averages: task => Evaluation.averages of its run
  def compare(averages)
    tasks.flat_map do |task, minimums|
      minimums.map { |score, minimum| Row.new(task: task, score: score, minimum: minimum, value: averages.dig(task, score)) }
    end
  end
end
