require "test_helper"

# The commands people run themselves: a run compares itself with the previous one, the baseline is rewritten only
# on purpose, and a promotion can always be rolled back.
class EvalWorkflowTest < ActiveSupport::TestCase
  include TracingTestHelper

  test "a run prints how each score moved since the previous run, and which variant that was" do
    Dir.mktmpdir do |dir|
      history = Evaluation::History.new("retrieval", dir: dir)
      assert_nil history.previous
      history.record("oxybot-haiku product-agent@v3", { "recall_at_5_hybrid" => 0.82, "mrr_hybrid" => 0.875 })

      previous = Evaluation::History.new("retrieval", dir: dir).previous
      lines = Evaluation::History.lines({ "recall_at_5_hybrid" => 0.86, "mrr_hybrid" => 0.875, "mrr_text" => 0.6 }, previous)

      assert_equal "oxybot-haiku product-agent@v3", previous.variant
      assert_match(/recall_at_5_hybrid\s+0\.820 -> 0\.860  \(\+0\.040\)/, lines[0])
      assert_match(/mrr_hybrid\s+0\.875 -> 0\.875  \(same\)/, lines[1])
      assert_match(/mrr_text\s+0\.600\z/, lines[2], "a new score has nothing to compare with")
    end
  end

  test "the baseline written from a run is a valid baseline with the measured minimums, rounded down" do
    text = Evaluation::Baseline.text("oxybot-haiku", { "matching" => { "correct" => 0.9091 }, "injection" => { "resisted" => 1.0 } })
    baseline = Evaluation::Baseline.new(YAML.safe_load(text))

    assert_equal({ "matching" => { "correct" => 0.9 }, "injection" => { "resisted" => 1.0 } }, baseline.tasks)
    assert baseline.compare("matching" => { "correct" => 0.9091 }, "injection" => { "resisted" => 1.0 }).all?(&:passed?), "the run it came from passes it"
  end

  test "promote makes the candidate production and remembers the replaced version; rollback restores it" do
    with_langfuse do
      stub_version("candidate", 6)
      stub_version("production", 5)
      relabel6 = stub_request(:patch, "http://langfuse.test/api/public/v2/prompts/product-agent/versions/6")
                   .with(body: { newLabels: %w[production candidate] }.to_json).to_return(body: "{}")
      relabel5 = stub_request(:patch, "http://langfuse.test/api/public/v2/prompts/product-agent/versions/5")
                   .with(body: { newLabels: %w[production] }.to_json).to_return(body: "{}")
      PromptRollout.create!(prompt_name: "product-agent", share: 20)

      assert_equal [ 5, 6 ], PromptRollout.promote!("product-agent")
      assert_requested relabel6
      assert_equal [ 0, 5 ], PromptRollout.find_by(prompt_name: "product-agent").slice(:share, :previous_version).values

      assert_equal "product-agent: v5 is production again", PromptRollout.rollback!("product-agent")
      assert_requested relabel5
      assert_nil PromptRollout.find_by(prompt_name: "product-agent").previous_version
      assert_raises(PromptRollout::Error) { PromptRollout.rollback!("product-agent") }
    end
  end

  test "rollback during a rollout stops it; promoting what is already production is refused" do
    PromptRollout.create!(prompt_name: "feature-judge", share: 30)
    assert_equal "feature-judge: rollout stopped, everyone gets production", PromptRollout.rollback!("feature-judge")
    assert_equal 0, PromptRollout.find_by(prompt_name: "feature-judge").share

    with_langfuse do
      stub_version("candidate", 5)
      stub_version("production", 5)
      assert_raises(PromptRollout::Error) { PromptRollout.promote!("product-agent") }
    end
  end

  private

  def stub_version(label, version)
    stub_request(:get, "http://langfuse.test/api/public/v2/prompts/product-agent?label=#{label}")
      .to_return(body: { type: "text", version: version, prompt: "x", config: {} }.to_json)
  end
end

class EvalTasksLoadTest < ActiveSupport::TestCase
  test "the eval and prompt tasks load without the app, as bin/rails -T loads them" do
    output = `cd #{Rails.root} && bin/rails -T evals 2>&1; bin/rails -T prompts 2>&1`

    assert_includes output, "evals:run"
    assert_includes output, "prompts:rollback"
    assert_not_includes output, "aborted"
  end

  test "the evals:run description names every task" do
    output = `cd #{Rails.root} && bin/rails -D evals:run 2>&1`

    Evaluation::TASKS.each { |task| assert_includes output, task }
  end
end
