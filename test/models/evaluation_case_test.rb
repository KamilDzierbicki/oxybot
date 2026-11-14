require "test_helper"

class EvaluationCaseTest < ActiveSupport::TestCase
  include TracingTestHelper

  setup do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    @insight = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "Email me the report weekly",
                                     summary: "Weekly report by email", suggested_feature: features(:pdf_export), match_reason: "judged")
  end

  test "linking another feature than the suggestion records the correction for review" do
    @insight.link_to(features(:scheduled_reports))

    evaluation_case = EvaluationCase.find_by!(insight: @insight)
    assert evaluation_case.pending?
    assert_equal({ "product" => "reports", "input" => "Weekly report by email" }, evaluation_case.input)
    assert_equal [ "Scheduled email reports", "PDF export of reports" ], evaluation_case.expected.values_at("feature", "suggested")
  end

  test "agreeing with the suggestion, or a judge that never ran, records nothing" do
    @insight.link_to(features(:pdf_export))
    unjudged = @insight.feedback_note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "q", summary: "s")
    unjudged.link_to(features(:scheduled_reports))

    assert_equal 0, EvaluationCase.count
  end

  test "undo removes a case still waiting for review, and a reviewed case keeps its decision" do
    @insight.link_to(features(:scheduled_reports))
    @insight.restore
    assert_equal 0, EvaluationCase.count

    @insight.link_to(features(:scheduled_reports))
    EvaluationCase.last.review("rejected", by: users(:kamil))
    @insight.restore
    @insight.link_to(features(:scheduled_reports))
    assert_equal "rejected", EvaluationCase.last.status
  end

  test "approved cases join the matching experiment; pending and rejected do not" do
    @insight.link_to(features(:scheduled_reports))
    pending_items = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme)).items
    EvaluationCase.last.review("approved", by: users(:kamil))
    approved_items = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme)).items

    assert_equal 1, approved_items.size - pending_items.size
    assert_equal({ "feature" => "Scheduled email reports" }, approved_items.last["expected"])
  end

  test "a case's customer text stays out of Langfuse unless traces may carry content" do
    start_tracing
    @insight.link_to(features(:scheduled_reports))
    EvaluationCase.last.review("approved", by: users(:kamil))
    stub_request(:get, %r{langfuse\.test/api/public/v2/datasets/oxybot-matching}).to_return(body: { id: "ds" }.to_json)
    items = stub_request(:post, "http://langfuse.test/api/public/dataset-items").to_return(body: "{}")
    stub_request(:post, "http://langfuse.test/api/public/scores").to_return(body: "{}")
    stub_request(:get, %r{langfuse\.test/api/public/v2/prompts}).to_return(status: 404, body: "{}")
    evaluation = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@items, [ EvaluationCase.last.to_item ])

    with_langfuse { evaluation.run }

    assert_not_requested items
    root = finished_spans.find { |span| span.name == "experiment-item" }
    assert_not_includes root.attributes["langfuse.observation.input"], "Weekly report by email"
  ensure
    stop_tracing
  end
end
