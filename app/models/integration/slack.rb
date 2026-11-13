# The account's Slack workspace (external_id is the team id). Slack has two roles, and code decides which:
# a message in a feedback channel becomes a FeedbackNote; a mention of the app or a direct message is a
# question for the assistant, answered in the thread.
class Integration::Slack < Integration
  has_many :slack_messages, foreign_key: :integration_id, dependent: :destroy

  store_accessor :settings, :feedback_channel_ids, :app_user_id, :report_channel_id

  # Takes the "event" part of an Events API callback. Duplicate deliveries hit the unique index and stop here.
  def receive(event)
    return unless event["type"].in?(%w[message app_mention])
    return if event["bot_id"] || event["subtype"] || event["text"].blank?

    message = slack_messages.create_or_find_by!(channel_id: event["channel"], ts: event["ts"]) do |record|
      record.direction = "inbound"
      record.thread_ts = event["thread_ts"]
      record.slack_user_id = event["user"]
      record.channel_type = event["channel_type"]
      record.mentions_app = event["type"] == "app_mention" || mentions_app?(event["text"])
      record.text = event["text"]
    end
    message.process_later if message.previously_new_record?
    message
  end

  def feedback_channel?(channel_id)
    Array(feedback_channel_ids).include?(channel_id)
  end

  def user_for(slack_user_id)
    account.users.find_by(slack_user_id: slack_user_id) if slack_user_id.present?
  end

  def post_reply(conversation, message)
    post_message(channel_id: conversation.slack_channel_id, thread_ts: conversation.slack_thread_ts, text: slack_text(message.content))
  end

  # Posts a finished document (the weekly opportunity report) to the report channel, shortened, with a link
  def post_document(document)
    return if report_channel_id.blank?

    link = Rails.application.routes.url_helpers.document_url(document, **Rails.application.config.x.url_options)
    post_message(channel_id: report_channel_id, text: slack_text("**#{document.title}**\n\n#{document.body.truncate(2_500)}\n\n<#{link}|Open in OxyBot>"))
  end

  def post_message(channel_id:, text:, thread_ts: nil)
    ts = mock? ? format("%.6f", Time.current.to_f) : client.post_message(channel: channel_id, text: text, thread_ts: thread_ts)
    slack_messages.create!(direction: "outbound", channel_id: channel_id, ts: ts, thread_ts: thread_ts,
                           slack_user_id: app_user_id, text: text)
  end

  def strip_mention(text)
    text.to_s.gsub(/<@#{Regexp.escape(app_user_id.to_s)}>/, "").strip
  end

  private

  def mentions_app?(text)
    app_user_id.present? && text.include?("<@#{app_user_id}>")
  end

  def client
    Integration::Slack::Client.new(access_token)
  end

  # Slack's mrkdwn: bold is *text*, headings become bold lines, citations become links to the insight in OxyBot
  def slack_text(content)
    content.to_s.gsub(/^#+\s*(.+)$/, '**\1**').gsub(/\*\*(.+?)\*\*/, '*\1*').gsub(Message::CITATION) do
      "<#{Rails.application.routes.url_helpers.insight_url($1, **Rails.application.config.x.url_options)}|##{$1}>"
    end
  end
end
