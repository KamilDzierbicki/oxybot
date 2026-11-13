# Every chat message OxyBot received or sent, on any chat platform. Inbound ones are routed once by #process.
class ChatMessage < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  PRIVATE_SESSION_GAP = 1.hour

  belongs_to :integration

  normalizes :text, with: ->(text) { VisibleText.clean(text) }

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :channel_id, :message_id, :text, presence: true

  scope :chronologically, -> { order(:id) }

  delegate :account, to: :integration

  def inbound? = direction == "inbound"
  def private_chat? = channel_type == "im"

  def process_later
    ProcessChatMessageJob.perform_later(self)
  end

  def process
    return if processed_at || !inbound?

    if mentions_app || private_chat?
      answer
    elsif integration.feedback_channel?(channel_id)
      record_feedback
    end
    update!(processed_at: Time.current)
  end

  private

  def answer
    user = integration.user_for(external_user_id)
    unless user
      return integration.post_message(channel_id: channel_id, thread_id: private_chat? ? thread_id : thread_id || message_id, reply_url: response_url,
                                      text: "I don't know you yet. Add your #{integration.display_name} member id to your OxyBot profile.")
    end

    conversation = conversation_for(user)
    conversation.update!(reply_url: response_url) if response_url.present?
    conversation.ask(integration.strip_mention(text))
  end

  # A private chat continues one rolling conversation with plain replies, like talking to a colleague; after a
  # quiet hour it starts fresh. A thread in a channel is its own conversation.
  def conversation_for(user)
    scope = account.conversations.where(integration: integration)
    if private_chat? && thread_id.blank?
      scope.where(user: user, chat_channel_id: channel_id, chat_thread_id: nil).where(updated_at: PRIVATE_SESSION_GAP.ago..).order(:updated_at).last ||
        scope.create!(user: user, channel: integration.kind, chat_channel_id: channel_id, private_chat: true)
    else
      scope.create_or_find_by!(chat_channel_id: channel_id, chat_thread_id: thread_id || message_id) do |record|
        record.user = user
        record.channel = integration.kind
        record.private_chat = private_chat?
      end
    end
  end

  def record_feedback
    author = integration.user_for(external_user_id)
    account.feedback_notes.create_or_find_by!(source: integration.kind, external_id: "#{channel_id}:#{message_id}") do |note|
      note.body = text
      note.author = author&.name || external_user_id
    end
  end
end
