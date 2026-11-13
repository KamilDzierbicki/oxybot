# Every Slack message OxyBot received or sent. Inbound ones are routed once by #process.
class SlackMessage < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  DM_SESSION_GAP = 1.hour

  belongs_to :integration, class_name: "Integration::Slack"

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :channel_id, :ts, :text, presence: true

  scope :chronologically, -> { order(:id) }

  delegate :account, to: :integration

  def inbound? = direction == "inbound"

  def process_later
    ProcessSlackMessageJob.perform_later(self)
  end

  def process
    return if processed_at || !inbound?

    if addressed_to_app?
      answer
    elsif integration.feedback_channel?(channel_id)
      record_feedback
    end
    update!(processed_at: Time.current)
  end

  def addressed_to_app?
    mentions_app || direct_message?
  end

  private

  def answer
    user = integration.user_for(slack_user_id)
    unless user
      return integration.post_message(channel_id: channel_id, thread_ts: direct_message? ? thread_ts : thread_ts || ts,
                                      text: "I don't know you yet. Ask an admin to add your Slack member ID to your OxyBot profile.")
    end

    conversation_for(user).ask(integration.strip_mention(text))
  end

  # A direct message continues one rolling conversation with plain replies, like chatting with a colleague;
  # after a quiet hour it starts fresh. A Slack thread (in a channel, or one started in the DM) is its own conversation.
  def conversation_for(user)
    if direct_message? && thread_ts.blank?
      account.conversations.where(user: user, slack_channel_id: channel_id, slack_thread_ts: nil)
             .where(updated_at: DM_SESSION_GAP.ago..).order(:updated_at).last ||
        account.conversations.create!(user: user, channel: "slack", slack_channel_id: channel_id)
    else
      account.conversations.create_or_find_by!(slack_channel_id: channel_id, slack_thread_ts: thread_ts || ts) do |record|
        record.user = user
        record.channel = "slack"
      end
    end
  end

  def direct_message? = channel_type == "im" || channel_id.start_with?("D")

  def record_feedback
    author = integration.user_for(slack_user_id)
    account.feedback_notes.create_or_find_by!(source: "slack", external_id: "#{channel_id}:#{ts}") do |note|
      note.body = text
      note.author = author&.name || slack_user_id
    end
  end
end
