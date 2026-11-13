# A self-hosted Mattermost team (external_id is the team id). Three entry points, as Mattermost allows:
#   outgoing webhook on feedback channels (no trigger word): every message becomes feedback
#   outgoing webhook with a trigger word ("@oxybot") in public channels: a question, answered in its thread
#   slash command ("/oxybot ...") anywhere, also in direct messages: a private (ephemeral) answer
class Integration::Mattermost < Integration
  include Chat

  encrypts :command_token
  encrypts :webhook_secret

  store_accessor :settings, :server_url, :trigger_word

  validates :server_url, format: { with: %r{\Ahttps?://[^\s/]+/?\z}, message: "must be the server's address, like https://chat.example.com" }

  def self.external_id_label = "Team id (System Console, Teams, or /api/v4/teams)"

  def trigger_word = super.presence || "@oxybot"

  # Outgoing webhook payload (form or JSON). The token is checked by the controller.
  def receive_webhook(params)
    text = params["text"].to_s
    mentioned = params["trigger_word"].present? || text.start_with?(trigger_word)
    receive_message(channel_id: params["channel_id"], message_id: params["post_id"], user_id: params["user_id"], text: text,
                    mentions_app: mentioned, private: false)
  end

  # Slash command payload. Answers go back through response_url as an ephemeral post only the asker sees.
  def receive_command(params)
    receive_message(channel_id: params["channel_id"], message_id: "command-#{params["trigger_id"].presence || SecureRandom.hex(8)}",
                    user_id: params["user_id"], text: params["text"].presence || "What should I look at first?",
                    private: true, mentions_app: true, response_url: trusted_response_url(params["response_url"]))
  end

  def valid_webhook_token?(token) = token_matches?(webhook_secret, token)
  def valid_command_token?(token) = token_matches?(command_token, token)

  def verify_connection
    me = client.me
    update!(app_user_id: me["id"]) if app_user_id.blank?
    [ true, "Connected to #{server_url} as @#{me["username"]}." ]
  end

  def strip_mention(text)
    text.to_s.delete_prefix(trigger_word).strip
  end

  def user_identity_column = :mattermost_user_id

  def format_link(url, label) = "[#{label}](#{url})"

  private

  def deliver(channel_id:, text:, thread_id:, reply_url:)
    reply_url ? client.respond(reply_url, text) : client.create_post(channel_id: channel_id, message: text, root_id: thread_id)
  end

  def client
    Integration::Mattermost::Client.new(server_url, access_token)
  end

  # Several tokens may be saved (one per outgoing webhook), comma separated
  def token_matches?(stored, token)
    token.present? && stored.to_s.split(/[\s,]+/).any? { |candidate| ActiveSupport::SecurityUtils.secure_compare(candidate, token) }
  end

  # Only URLs on our own Mattermost server are called back, so a forged command cannot make OxyBot call elsewhere
  def trusted_response_url(url)
    url if url.present? && URI.parse(url).host == URI.parse(server_url).host
  rescue URI::InvalidURIError
    nil
  end
end
