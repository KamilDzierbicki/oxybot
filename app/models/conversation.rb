# A chat with the product assistant, in the web app or in a Slack thread. Chats are private to their user.
class Conversation < ApplicationRecord
  CHANNELS = %w[web slack].freeze

  belongs_to :account
  belongs_to :user
  has_many :messages, -> { order(:id) }, dependent: :destroy

  validates :channel, inclusion: { in: CHANNELS }

  scope :latest_first, -> { order(updated_at: :desc, id: :desc) }

  # Saves the question and an empty reply, then fills the reply in a job: a model turn takes seconds.
  def ask(text)
    reply = transaction do
      messages.create!(role: "user", content: text)
      update!(title: text.truncate(80)) if title.blank?
      messages.create!(role: "assistant", status: "thinking")
    end
    reply.generate_later
    reply
  end

  def slack? = channel == "slack"

  # In a Slack channel every member reads the answer, so customer revenue stays out of it.
  # Direct messages (channel ids starting with D) and the web app are private to the user.
  def revenue_visible?
    !slack? || slack_channel_id.to_s.start_with?("D")
  end
end
