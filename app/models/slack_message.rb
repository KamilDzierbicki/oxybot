# Every Slack message OpenSpark received or sent. Inbound ones are routed once by #process.
class SlackMessage < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze

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
    mentions_app || channel_type == "im" || channel_id.start_with?("D")
  end

  private

  def answer
    user = integration.user_for(slack_user_id)
    unless user
      return integration.post_message(channel_id: channel_id, thread_ts: thread_ts || ts,
                                      text: "I don't know you yet. Ask an admin to add your Slack member ID to your OpenSpark profile.")
    end

    conversation = account.conversations.create_or_find_by!(slack_channel_id: channel_id, slack_thread_ts: thread_ts || ts) do |record|
      record.user = user
      record.channel = "slack"
    end
    conversation.ask(integration.strip_mention(text))
  end

  def record_feedback
    author = integration.user_for(slack_user_id)
    account.feedback_notes.create_or_find_by!(source: "slack", external_id: "#{channel_id}:#{ts}") do |note|
      note.body = text
      note.author = author&.name || slack_user_id
    end
  end
end
