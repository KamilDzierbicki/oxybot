# What Slack and Mattermost share: messages in feedback channels become feedback, messages addressed to the app
# are questions for the assistant, and answers go back to the same place. A platform adapter only parses its
# events (into #receive_message) and delivers text (#deliver).
module Integration::Chat
  extend ActiveSupport::Concern

  included do
    has_many :chat_messages, foreign_key: :integration_id, dependent: :destroy
    has_many :conversations, foreign_key: :integration_id, dependent: :nullify
    store_accessor :settings, :feedback_channel_ids, :app_user_id, :report_channel_id
  end

  # attributes: channel_id, message_id, thread_id, user_id, text, private (DM or private command), mentions_app, response_url
  def receive_message(attributes)
    return if attributes[:text].blank? || attributes[:user_id].blank? || attributes[:user_id] == app_user_id

    message = chat_messages.create_or_find_by!(channel_id: attributes[:channel_id], message_id: attributes[:message_id]) do |record|
      record.direction = "inbound"
      record.thread_id = attributes[:thread_id].presence
      record.external_user_id = attributes[:user_id]
      record.channel_type = attributes[:private] ? "im" : "channel"
      record.mentions_app = attributes[:mentions_app].present?
      record.response_url = attributes[:response_url]
      record.text = attributes[:text]
    end
    message.process_later if message.previously_new_record?
    message
  end

  def feedback_channel?(channel_id)
    Array(feedback_channel_ids).include?(channel_id)
  end

  def post_reply(conversation, message)
    post_message(channel_id: conversation.chat_channel_id, thread_id: conversation.chat_thread_id,
                 text: format_text(message.content), reply_url: conversation.reply_url)
  end

  # Posts a finished document (the weekly opportunity report) to the report channel, shortened, with a link
  def post_document(document)
    return if report_channel_id.blank?

    link = Rails.application.routes.url_helpers.document_url(document, **Rails.application.config.x.url_options)
    post_message(channel_id: report_channel_id, text: format_text("**#{document.title}**\n\n#{document.body.truncate(2_500)}") + "\n\n" + format_link(link, "Open in OxyBot"))
  end

  # Mock mode records the reply instead of sending it
  def post_message(channel_id:, text:, thread_id: nil, reply_url: nil)
    message_id = mock? ? "mock-#{SecureRandom.hex(6)}" : deliver(channel_id: channel_id, text: text, thread_id: thread_id, reply_url: reply_url)
    chat_messages.create!(direction: "outbound", channel_id: channel_id, message_id: message_id, thread_id: thread_id,
                          external_user_id: app_user_id, text: text)
  end

  # Citations become links to the insight in OxyBot, in the platform's link syntax
  def format_text(content)
    content.to_s.gsub(Message::CITATION) do
      format_link(Rails.application.routes.url_helpers.insight_url($1, **Rails.application.config.x.url_options), "##{$1}")
    end
  end

  def user_for(external_user_id)
    account.users.find_by(user_identity_column => external_user_id) if external_user_id.present?
  end
end
