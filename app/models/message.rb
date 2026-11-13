class Message < ApplicationRecord
  ROLES = %w[user assistant].freeze
  STATUSES = %w[thinking done failed].freeze
  CITATION = /\[insight:(\d+)\]/

  belongs_to :conversation, touch: true

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :content, presence: true, if: -> { status == "done" }

  after_create_commit -> { broadcast_append_to conversation, target: "messages" }
  after_update_commit -> { broadcast_replace_to conversation }

  def user? = role == "user"
  def assistant? = role == "assistant"
  def thinking? = status == "thinking"
  def failed? = status == "failed"

  def generate_later
    GenerateReplyJob.perform_later(self)
  end

  def generate
    Conversation::Turn.new(self).run
  end
end
