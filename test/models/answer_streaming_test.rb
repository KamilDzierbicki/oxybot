require "test_helper"
require "turbo/broadcastable/test_helper"

# A web answer appears while the model writes it; the finished reply then replaces the plain streamed text with
# checked markdown. Chat channels get only the finished answer.
class AnswerStreamingTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  test "a web answer is streamed into the reply's body as plain text, then the finished reply replaces it" do
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))
    conversation.ask("What do customers say about PDF export?")
    reply = conversation.messages.last
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_includes llm_requests("oxybot-assistant").last.body, %("stream":true)
    streamed = capture_turbo_stream_broadcasts(conversation).select { |stream| stream["target"] == "body_message_#{reply.id}" }
    assert_not_empty streamed, "the answer reached the page before it was finished"
    assert_includes streamed.last.to_html, %(aria-busy="true")
    assert_equal "done", reply.reload.status
    streamed_text = Nokogiri::HTML5.fragment(streamed.last.at("template").inner_html).text
    assert reply.content.start_with?(streamed_text), "the streamed text is the start of the answer the reply keeps"
  end

  test "a Slack conversation is not streamed" do
    conversation = accounts(:acme).conversations.create!(user: users(:kamil), channel: "slack", integration: integrations(:acme_slack),
                                                         chat_channel_id: "D_KAMIL", private_chat: true)
    conversation.ask("What do customers say about PDF export?")
    stub_request(:post, /slack\.com/).to_return(body: { ok: true, ts: "1.1" }.to_json)
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_not_includes llm_requests("oxybot-assistant").last.body, %("stream":true)
  end

  test "streamed text is escaped, so feedback quoted by the model cannot inject markup" do
    reply = users(:kamil).conversations.create!(account: accounts(:acme)).messages.create!(role: "assistant", status: "thinking")
    stream = Conversation::Stream.new(reply)

    stream << RubyLLM::Chunk.new(role: :assistant, content: "<img src=x onerror=alert(1)> PDF")

    html = capture_turbo_stream_broadcasts(reply.conversation).last.to_html
    assert_includes html, "&lt;img src=x onerror=alert(1)&gt;"
  end
end
