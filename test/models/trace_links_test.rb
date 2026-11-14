require "test_helper"

# The weekly error review starts in Langfuse: every OxyBot root span names the record it worked on and links to it,
# so a reviewer can open the insight, note, document or answer in OxyBot. Only ids and the link, never text.
class TraceLinksTest < ActiveSupport::TestCase
  include TracingTestHelper

  setup { start_tracing }
  teardown { stop_tracing }

  test "a match names its insight and stores the judge's model call for the score" do
    embed_features
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    insight = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "PDF please", summary: "PDF export")

    insight.match

    root = root_span("match-insight")
    assert_equal({ "insight_id" => insight.id.to_s, "oxybot_url" => "http://localhost:3120/insights/#{insight.id}" }, trace_metadata(root))
    assert_equal judge_call(root).hex_span_id, insight.reload.match_observation_id
  end

  test "an extraction names its note and stores the extractor's model call" do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "We need PDF export of the weekly report.")
    note.extract_insights

    root = root_span("extract-insights")
    assert_equal({ "feedback_note_id" => note.id.to_s, "oxybot_url" => "http://localhost:3120/feedback_notes/#{note.id}" }, trace_metadata(root))
    assert_equal judge_call(root).hex_span_id, note.reload.extraction_observation_id
  end

  test "drafting and revising a document name the document, and a revision its suggestion" do
    document = accounts(:acme).documents.create!(kind: "prd", title: "Spec: PDF export", status: "drafting", creator: users(:kamil),
                                                 feature: features(:pdf_export))
    document.generate
    assert_equal({ "document_id" => document.id.to_s, "oxybot_url" => "http://localhost:3120/documents/#{document.id}" },
                 trace_metadata(root_span("draft-document")))

    suggestion = document.reload.suggestions.create!(instruction: "Shorten the summary", status: "thinking", user: users(:kamil))
    Document::Revision.new(suggestion).run
    root = root_span("revise-document")
    assert_equal({ "document_id" => document.id.to_s, "suggestion_id" => suggestion.id.to_s,
                   "oxybot_url" => "http://localhost:3120/documents/#{document.id}#document_suggestion_#{suggestion.id}" }, trace_metadata(root))
    assert_equal judge_call(root).hex_span_id, suggestion.reload.observation_id
  end

  test "an answer names its conversation and message" do
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))
    reply = conversation.ask("What do customers say about PDF export?")
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_equal({ "conversation_id" => conversation.id.to_s, "message_id" => reply.id.to_s,
                   "oxybot_url" => "http://localhost:3120/conversations/#{conversation.id}#message_#{reply.id}" },
                 trace_metadata(root_span("assistant-turn")))
  end

  test "a person's decision is scored on the model call, where Langfuse knows its prompt version and model" do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    insight = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "PDF please", summary: "PDF",
                                    suggested_feature: features(:pdf_export))
    insight.update_columns(match_trace_id: "match-trace", match_observation_id: "judge-call")

    with_langfuse { insight.link_to(features(:pdf_export)) }

    score = enqueued_jobs.find { |job| job["job_class"] == "LangfuseScoreJob" && job["arguments"].first.end_with?("feature-match") }
    assert_equal [ "match-trace", "judge-call" ], score.dig("arguments", 1).values_at("traceId", "observationId")
  end

  private

  def root_span(name) = finished_spans.reverse.find { |span| span.name == name } || flunk("no #{name} span")

  def trace_metadata(span)
    span.attributes.select { |key, _| key.start_with?("langfuse.trace.metadata.") }.transform_keys { |key| key.delete_prefix("langfuse.trace.metadata.") }
  end

  # The model call a score is attached to: the last chat span in the root's trace
  def judge_call(root)
    finished_spans.select { |span| span.hex_trace_id == root.hex_trace_id && span.attributes["gen_ai.operation.name"] == "chat" }
                  .max_by(&:start_timestamp) || flunk("no model call in #{root.name}")
  end
end
