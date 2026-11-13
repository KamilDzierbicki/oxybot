require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  setup do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder", customer: customers(:northwind))
    @pdf = note.insights.create!(account: accounts(:acme), product: products(:reports), customer: customers(:northwind),
                                 quote: "We need PDF export of reports for the board", summary: "PDF export of reports for the board")
    @pdf.embed
    @pdf.link_to(features(:pdf_export))
  end

  test "answers from the search tool and keeps citations of insights the tool returned" do
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))

    reply = conversation.ask("What do customers say about PDF export?")
    perform_enqueued_jobs(only: GenerateReplyJob)

    reply.reload
    assert_equal "done", reply.status
    assert_equal ["search_feedback"], reply.tool_calls.map { |call| call["name"] }
    assert_equal [@pdf.id], reply.cited_insight_ids
    assert_includes reply.content, "Northwind Logistics"
    assert_includes reply.content, "$120,000", "the web app is private, so ARR is shown"
  end

  test "drops citations of insights no tool returned" do
    turn = Conversation::Turn.new(users(:kamil).conversations.create!(account: accounts(:acme)).messages.create!(role: "assistant", status: "thinking"))
    turn.remember_insights([@pdf.id])

    content, cited = turn.send(:checked_citations, "Real [insight:#{@pdf.id}] and invented [insight:999999].")

    assert_equal [@pdf.id], cited
    assert_not_includes content, "999999"
  end

  test "demand ranking counts each customer's ARR once" do
    second = @pdf.feedback_note.insights.create!(account: accounts(:acme), product: products(:reports), customer: customers(:northwind),
                                                 quote: "PDF again", summary: "PDF again")
    second.link_to(features(:pdf_export))

    feature = accounts(:acme).features.by_demand.first

    assert_equal features(:pdf_export), feature
    assert_equal 2, feature.insight_count
    assert_equal 1, feature.customer_count
    assert_equal customers(:northwind).arr_cents, feature.demand_arr_cents
  end

  test "a shared Slack channel never gets revenue" do
    conversation = accounts(:acme).conversations.create!(user: users(:kamil), channel: "slack", slack_channel_id: "C_GENERAL", slack_thread_ts: "1.0")

    conversation.ask("Which features have the most demand?")
    perform_enqueued_jobs(only: GenerateReplyJob)

    reply = conversation.messages.last
    assert_equal ["feature_demand"], reply.tool_calls.map { |call| call["name"] }
    assert_not_includes reply.content, "$", "every member of a channel would read customer revenue"
    assert_includes reply.content, "PDF export of reports"
  end

  test "a direct message to the app may show revenue" do
    conversation = accounts(:acme).conversations.create!(user: users(:kamil), channel: "slack", slack_channel_id: "D_KAMIL", slack_thread_ts: "1.0")

    assert conversation.revenue_visible?
  end

  test "a failed model call leaves an error reply instead of a stuck spinner" do
    stub_request(:post, "http://mock-llm.test/v1/chat/completions").to_return(status: 500, body: { error: { message: "boom" } }.to_json)
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))

    reply = conversation.ask("Anything about PDF?")
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_equal "failed", reply.reload.status
  end
end
