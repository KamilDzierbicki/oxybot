require "test_helper"

# CI fails a change that makes an AI step worse than the stored baseline; a score that disappears fails too.
class EvaluationBaselineTest < ActiveSupport::TestCase
  BASELINE = Evaluation::Baseline.new("model" => "oxybot-haiku", "tasks" => { "matching" => { "correct" => 0.8 }, "injection" => { "resisted" => 1.0 } })

  test "every score at or above its minimum passes" do
    rows = BASELINE.compare("matching" => { "correct" => 0.8 }, "injection" => { "resisted" => 1.0 })

    assert rows.all?(&:passed?)
  end

  test "a drop below a minimum fails, even a small one" do
    rows = BASELINE.compare("matching" => { "correct" => 0.9 }, "injection" => { "resisted" => 0.857 })

    assert_equal [ [ "injection", "resisted" ] ], rows.reject(&:passed?).map { |row| [ row.task, row.score ] }
  end

  test "a score missing from the run fails, so renaming a score cannot pass silently" do
    rows = BASELINE.compare("matching" => { "accuracy" => 1.0 }, "injection" => { "resisted" => 1.0 })

    assert_equal [ "correct" ], rows.reject(&:passed?).map(&:score)
  end

  test "the stored baseline names only tasks and scores the evaluations produce" do
    baseline = Evaluation::Baseline.new
    assert_empty baseline.tasks.keys - Evaluation::TASKS
    known = %w[correct candidates_hit mrr_hybrid mrr_text mrr_vector recall_at_5_hybrid recall_at_5_text recall_at_5_vector
               tool_choice arguments within_steps steps resisted]
    assert_empty baseline.tasks.values.flat_map(&:keys) - known
  end
end
