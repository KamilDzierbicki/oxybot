# A chat with the product assistant, in the web app or in a Slack thread. Chats are private to their user.
class Conversation < ApplicationRecord
  CHANNELS = %w[web slack mattermost].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :integration, optional: true
  has_many :messages, -> { order(:id) }, dependent: :destroy

  validates :channel, inclusion: { in: CHANNELS }

  scope :latest_first, -> { order(updated_at: :desc, id: :desc) }

  # Saves the question and an empty reply, then fills the reply in a job: a model turn takes seconds.
  # Two separate commits on purpose: each message is broadcast on commit, and inside one transaction the
  # broadcasts could reach the page in the wrong order. The question is saved first, so it survives a failure.
  def ask(text)
    messages.create!(role: "user", content: text)
    update!(title: text.truncate(80)) if title.blank?
    reply = messages.create!(role: "assistant", status: "thinking")
    reply.generate_later
    reply
  end

  def chat? = integration_id.present?

  # In a chat channel every member reads the answer, so customer revenue stays out of it.
  # Direct messages, slash command answers (only the asker sees them) and the web app are private.
  def revenue_visible?
    !chat? || private_chat?
  end
end
