require "test_helper"

class Slack::EventsControllerTest < ActionDispatch::IntegrationTest
  SECRET = "oxybot-local-signing-secret"

  test "answers Slack's URL verification" do
    post_signed({ type: "url_verification", challenge: "abc123" })

    assert_response :success
    assert_equal "abc123", response.parsed_body["challenge"]
  end

  test "refuses a request with a wrong signature" do
    post slack_events_path, params: { type: "url_verification", challenge: "x" }.to_json,
                            headers: { "X-Slack-Request-Timestamp" => Time.current.to_i.to_s, "X-Slack-Signature" => "v0=forged", "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  test "refuses a replayed request older than five minutes" do
    post_signed({ type: "url_verification", challenge: "x" }, timestamp: 10.minutes.ago.to_i)

    assert_response :unauthorized
  end

  test "a message in a feedback channel becomes feedback, once even if Slack redelivers it" do
    event = message_event(channel: "C_FEEDBACK", text: "Customers keep asking for PDF export of reports.")

    assert_difference -> { accounts(:acme).feedback_notes.where(source: "slack").count }, 1 do
      2.times { post_signed(event) }
      perform_enqueued_jobs(only: ProcessSlackMessageJob)
    end
  end

  test "a message in another channel is ignored" do
    assert_no_difference -> { FeedbackNote.count } do
      post_signed(message_event(channel: "C_RANDOM", text: "Lunch at noon?"))
      perform_enqueued_jobs(only: ProcessSlackMessageJob)
    end
  end

  test "a mention is answered in the thread with linked citations" do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder", customer: customers(:northwind))
    insight = note.insights.create!(account: accounts(:acme), product: products(:reports), customer: customers(:northwind),
                                    quote: "PDF export of reports please", summary: "PDF export of reports")
    insight.embed

    post_signed(message_event(channel: "C_GENERAL", text: "<@U_OXYBOT> what do customers say about PDF export?", type: "app_mention", ts: "1700000000.000100"))
    perform_enqueued_jobs(only: ProcessSlackMessageJob)
    perform_enqueued_jobs(only: GenerateReplyJob) # enqueued by the first job

    reply = integrations(:acme_slack).slack_messages.find_by!(direction: "outbound")
    assert_equal "1700000000.000100", reply.thread_ts
    assert_includes reply.text, "/insights/#{insight.id}|##{insight.id}>"
    assert_not_includes reply.text, "$", "a shared channel never sees revenue"
  end

  test "a Slack user without a OxyBot account gets no data" do
    post_signed(message_event(channel: "D_STRANGER", text: "what do customers want?", user: "U_STRANGER"))
    perform_enqueued_jobs(only: ProcessSlackMessageJob)

    reply = integrations(:acme_slack).slack_messages.find_by!(direction: "outbound")
    assert_match "I don't know you yet", reply.text
    assert_equal 0, Conversation.count
  end

  test "an event from another workspace never reaches this tenant" do
    post_signed(message_event(channel: "C_FEEDBACK", text: "Customers keep asking for PDF export.", team: "T_UNKNOWN"))

    assert_equal 0, SlackMessage.count
  end

  private

  def message_event(channel:, text:, type: "message", user: "U_KAMIL", ts: "1700000000.000001", team: "T_ACME")
    { type: "event_callback", team_id: team,
      event: { type: type, channel: channel, channel_type: channel.start_with?("D") ? "im" : "channel", user: user, text: text, ts: ts } }
  end

  def post_signed(payload, timestamp: Time.current.to_i)
    body = payload.to_json
    signature = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", SECRET, "v0:#{timestamp}:#{body}")}"
    post slack_events_path, params: body,
                            headers: { "X-Slack-Request-Timestamp" => timestamp.to_s, "X-Slack-Signature" => signature, "Content-Type" => "application/json" }
  end
end
