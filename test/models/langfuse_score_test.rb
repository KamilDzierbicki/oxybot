require "test_helper"

# A person's decision becomes a 0/1 score on the trace of the model call it judges, and nothing else leaves OxyBot.
class LangfuseScoreTest < ActiveSupport::TestCase
  include TracingTestHelper

  setup do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    note.update_columns(extraction_trace_id: "extract-trace")
    @insight = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "PDF please", summary: "PDF",
                                     suggested_feature: features(:pdf_export))
    @insight.update_columns(match_trace_id: "match-trace")
  end

  test "linking the suggested feature scores the judge right and the extraction useful" do
    with_langfuse { @insight.link_to(features(:pdf_export)) }

    assert_score "oxybot-insight-#{@insight.id}-feature-match", trace: "match-trace", name: "feature_match", value: 1
    assert_score "oxybot-insight-#{@insight.id}-kept", trace: "extract-trace", name: "insight_kept", value: 1
  end

  test "linking another feature scores the judge wrong" do
    other = products(:reports).features.where.not(id: features(:pdf_export).id).first || products(:reports).features.create!(account: accounts(:acme), title: "Other", description: "x")

    with_langfuse { @insight.link_to(other) }

    assert_score "oxybot-insight-#{@insight.id}-feature-match", trace: "match-trace", name: "feature_match", value: 0
  end

  test "a new feature is the right call only when the judge found none" do
    @insight.update_columns(suggested_feature_id: nil)
    feature = products(:reports).features.create!(account: accounts(:acme), title: "Brand new", description: "x")

    with_langfuse { @insight.reload.link_to(feature, created: true) }

    assert_score "oxybot-insight-#{@insight.id}-feature-match", trace: "match-trace", name: "feature_match", value: 1
  end

  test "dismissing scores the extraction wrong; undo removes the scores" do
    with_langfuse { @insight.dismiss }
    assert_score "oxybot-insight-#{@insight.id}-kept", trace: "extract-trace", name: "insight_kept", value: 0

    clear_enqueued_jobs
    with_langfuse { @insight.restore }
    removed = enqueued_jobs.select { |job| job["job_class"] == "LangfuseScoreJob" && job["arguments"].last.nil? }.map { |job| job["arguments"].first }
    assert_equal [ "oxybot-insight-#{@insight.id}-feature-match", "oxybot-insight-#{@insight.id}-kept" ], removed.sort
  end

  test "accepting and rejecting a suggestion score the reviser's call" do
    document = accounts(:acme).documents.create!(kind: "prd", title: "Spec", status: "ready", body: "a")
    accepted = document.suggestions.create!(instruction: "x", status: "pending", body: "b", rationale: "r", trace_id: "revise-1")
    rejected = document.suggestions.create!(instruction: "y", status: "pending", body: "c", rationale: "r", trace_id: "revise-2")

    with_langfuse do
      accepted.accept(user: users(:kamil))
      rejected.reject
    end

    assert_score "oxybot-suggestion-#{accepted.id}-accepted", trace: "revise-1", name: "suggestion_accepted", value: 1
    assert_score "oxybot-suggestion-#{rejected.id}-accepted", trace: "revise-2", name: "suggestion_accepted", value: 0
  end

  test "no trace (tracing off) or no Langfuse means no score" do
    @insight.update_columns(match_trace_id: nil)
    with_langfuse { @insight.link_to(features(:pdf_export)) }
    assert_no_score "oxybot-insight-#{@insight.id}-feature-match"

    clear_enqueued_jobs
    @insight.update_columns(match_trace_id: "match-trace")
    @insight.restore
    @insight.link_to(features(:pdf_export)) # Langfuse not configured
    assert_empty enqueued_jobs.select { |job| job["job_class"] == "LangfuseScoreJob" }
  end

  test "the score sent to Langfuse carries the decision and no text" do
    request = stub_request(:post, "http://langfuse.test/api/public/scores").to_return(body: "{}")

    with_langfuse { LangfuseScoreJob.perform_now("score-1", { "traceId" => "t", "name" => "feature_match", "value" => 1, "dataType" => "BOOLEAN" }) }

    assert_requested request
    sent = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
    assert_equal %w[dataType id name traceId value], sent.keys.sort
  end

  test "removing a score that is already gone is fine" do
    stub_request(:delete, "http://langfuse.test/api/public/scores/score-1").to_return(status: 404, body: "{}")

    with_langfuse { assert_nothing_raised { LangfuseScoreJob.perform_now("score-1", nil) } }
  end

  test "a match records the trace of its own model call" do
    start_tracing
    @insight.update_columns(match_trace_id: nil)
    embed_features

    @insight.match
    root = finished_spans.find { |span| span.name == "match-insight" }

    assert root
    assert_equal root.hex_trace_id, @insight.reload.match_trace_id
    assert finished_spans.any? { |span| span.hex_trace_id == root.hex_trace_id && span.attributes["gen_ai.operation.name"] == "chat" },
           "the judge's model call belongs to the same trace"
  ensure
    stop_tracing
  end

  private

  def score_jobs(id)
    enqueued_jobs.select { |job| job["job_class"] == "LangfuseScoreJob" && job["arguments"].first == id }
  end

  def assert_score(id, trace:, name:, value:)
    payload = score_jobs(id).last&.dig("arguments", 1)
    assert payload, "expected a score #{id}"
    assert_equal({ "traceId" => trace, "name" => name, "value" => value, "dataType" => "BOOLEAN", "environment" => "test" }, payload.except("_aj_symbol_keys", "_aj_hash_with_indifferent_access"))
  end

  def assert_no_score(id)
    assert_empty score_jobs(id).select { |job| job["arguments"].last }
  end
end
