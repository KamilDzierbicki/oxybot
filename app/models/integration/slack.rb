# The account's Slack workspace (external_id is the team id). Parses Events API callbacks and posts with the Web API.
class Integration::Slack < Integration
  include Chat

  def self.external_id_label = "Workspace (team) id, like T012ABCDEF"

  # Takes the "event" part of an Events API callback. Duplicate deliveries hit the unique index and stop.
  def receive(event)
    return unless event["type"].in?(%w[message app_mention])
    return if event["bot_id"] || event["subtype"]

    receive_message(channel_id: event["channel"], message_id: event["ts"], thread_id: event["thread_ts"], user_id: event["user"],
                    text: event["text"], private: event["channel_type"] == "im",
                    mentions_app: event["type"] == "app_mention" || (app_user_id.present? && event["text"].to_s.include?("<@#{app_user_id}>")))
  end

  # auth.test tells which workspace the token belongs to and the bot's member id (used to detect mentions)
  def verify_connection
    identity = client.auth_test
    return [ false, "The token belongs to workspace #{identity["team_id"]}, not #{external_id}." ] if identity["team_id"] != external_id

    update!(app_user_id: identity["user_id"]) if app_user_id.blank?
    [ true, "Connected to #{identity["team"]} as #{identity["user"]}." ]
  end

  def strip_mention(text)
    text.to_s.gsub(/<@#{Regexp.escape(app_user_id.to_s)}>/, "").strip
  end

  def user_identity_column = :slack_user_id

  # Slack's mrkdwn: headings and **bold** become *bold*
  def format_text(content)
    super(content.to_s.gsub(/^#+\s*(.+)$/, '**\1**').gsub(/\*\*(.+?)\*\*/, '*\1*'))
  end

  def format_link(url, label) = "<#{url}|#{label}>"

  private

  def deliver(channel_id:, text:, thread_id:, reply_url:)
    client.post_message(channel: channel_id, text: text, thread_ts: thread_id)
  end

  def client
    Integration::Slack::Client.new(access_token)
  end
end
