require "test_helper"

class Mattermost::IntegrationTest < ActionDispatch::IntegrationTest
  WEBHOOK_TOKEN = "mm-outgoing-token"
  COMMAND_TOKEN = "mm-command-token"

  setup do
    @mattermost = integrations(:acme_mattermost)
    @mattermost.update!(webhook_secret: "other-token, #{WEBHOOK_TOKEN}", command_token: COMMAND_TOKEN)
  end

  test "a message in a feedback channel becomes Mattermost feedback" do
    post mattermost_webhooks_path, params: webhook(channel_id: "mm-feedback", text: "Customers keep asking for PDF export of reports."), as: :json
    perform_enqueued_jobs(only: ProcessChatMessageJob)

    assert_response :ok
    assert_equal 1, accounts(:acme).feedback_notes.where(source: "mattermost").count
  end

  test "form-encoded webhooks work too" do
    post mattermost_webhooks_path, params: webhook(channel_id: "mm-feedback", text: "Reports are too slow to export.")

    assert_response :ok
  end

  test "a webhook with a wrong token is refused" do
    post mattermost_webhooks_path, params: webhook(channel_id: "mm-feedback", text: "x").merge(token: "forged"), as: :json

    assert_response :unauthorized
    assert_equal 0, ChatMessage.count
  end

  test "a question with the trigger word is answered in its thread, without revenue" do
    stub_request(:post, "https://chat.acme.example/api/v4/posts").to_return(body: { id: "reply-1" }.to_json)
    @mattermost.update!(access_token: "bot-token")

    post mattermost_webhooks_path, params: webhook(channel_id: "town-square", text: "@oxybot which features have the most demand?", trigger_word: "@oxybot"), as: :json
    perform_enqueued_jobs(only: ProcessChatMessageJob)
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_requested(:post, "https://chat.acme.example/api/v4/posts") { |request| JSON.parse(request.body)["root_id"] == "post-1" && !request.body.include?("$") }
  end

  test "a slash command is acknowledged at once and answered privately through its response URL" do
    response_url = "https://chat.acme.example/hooks/commands/abc"
    stub_request(:post, response_url).to_return(body: "{}")
    @mattermost.update!(access_token: "bot-token")

    post mattermost_commands_path, params: command(text: "which features have the most demand?", response_url: response_url),
                                   headers: { "Authorization" => "Token #{COMMAND_TOKEN}" }
    assert_equal "ephemeral", response.parsed_body["response_type"]

    perform_enqueued_jobs(only: ProcessChatMessageJob)
    perform_enqueued_jobs(only: GenerateReplyJob)
    assert_requested(:post, response_url) { |request| JSON.parse(request.body)["response_type"] == "ephemeral" && request.body.include?("$") }
  end

  test "a slash command cannot make OxyBot call another server" do
    @mattermost.update!(access_token: "bot-token")
    stub_request(:post, "https://chat.acme.example/api/v4/posts").to_return(body: { id: "p" }.to_json)

    post mattermost_commands_path, params: command(text: "hi", response_url: "https://attacker.example/steal"),
                                   headers: { "Authorization" => "Token #{COMMAND_TOKEN}" }
    perform_enqueued_jobs(only: ProcessChatMessageJob)
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_not_requested :post, "https://attacker.example/steal"
  end

  test "a slash command with a wrong token is refused" do
    post mattermost_commands_path, params: command(text: "hi", response_url: "https://chat.acme.example/x"), headers: { "Authorization" => "Token nope" }

    assert_response :unauthorized
  end

  private

  def webhook(channel_id:, text:, trigger_word: nil)
    { token: WEBHOOK_TOKEN, team_id: "mm-team-acme", channel_id: channel_id, channel_name: channel_id, post_id: "post-1",
      user_id: "mm-kamil", user_name: "kamil", text: text, trigger_word: trigger_word }.compact
  end

  def command(text:, response_url:)
    { team_id: "mm-team-acme", channel_id: "mm-dm-channel", user_id: "mm-kamil", command: "/oxybot", text: text,
      response_url: response_url, trigger_id: SecureRandom.hex(4) }
  end
end
