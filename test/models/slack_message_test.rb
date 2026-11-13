require "test_helper"

class SlackMessageTest < ActiveSupport::TestCase
  setup { @slack = integrations(:acme_slack) }

  test "a direct message continues the same conversation and replies without a thread" do
    2.times { |i| dm("Question #{i} about PDF export", ts: "1700000000.00000#{i}") }

    conversations = accounts(:acme).conversations.where(slack_channel_id: "D_KAMIL")
    assert_equal 1, conversations.count
    assert_equal 4, conversations.first.messages.count
    assert @slack.slack_messages.where(direction: "outbound").all? { |message| message.thread_ts.nil? }
  end

  test "after an hour of silence a direct message starts a new conversation" do
    dm("First question about PDF export", ts: "1700000000.000001")
    travel 2.hours do
      dm("A new topic about offline mode", ts: "1700000000.000002")
    end

    assert_equal 2, accounts(:acme).conversations.where(slack_channel_id: "D_KAMIL").count
  end

  test "a mention in a channel is answered in its thread" do
    @slack.receive("type" => "app_mention", "channel" => "C_GENERAL", "user" => "U_KAMIL", "text" => "<@U_OXYBOT> PDF?", "ts" => "1700000000.000009")
    perform_enqueued_jobs(only: ProcessSlackMessageJob)
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_equal "1700000000.000009", @slack.slack_messages.find_by!(direction: "outbound").thread_ts
  end

  private

  def dm(text, ts:)
    @slack.receive("type" => "message", "channel" => "D_KAMIL", "channel_type" => "im", "user" => "U_KAMIL", "text" => text, "ts" => ts)
    perform_enqueued_jobs(only: ProcessSlackMessageJob)
    perform_enqueued_jobs(only: GenerateReplyJob)
  end
end
