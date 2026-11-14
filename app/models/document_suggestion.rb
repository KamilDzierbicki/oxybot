# A change the agent proposes to a document after a person asked for it. It is applied only on accept.
class DocumentSuggestion < ApplicationRecord
  STATUSES = %w[thinking pending accepted rejected failed].freeze

  belongs_to :document, touch: true
  belongs_to :user, optional: true
  belongs_to :base_version, class_name: "DocumentVersion", optional: true

  validates :instruction, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: %w[thinking pending]) }

  def thinking? = status == "thinking"
  def pending? = status == "pending"

  def generate_later
    ReviseDocumentJob.perform_later(self)
  end

  def generate
    Document::Revision.new(self).run
  end

  # The document changed since the agent read it: accepting would throw that change away
  def stale?
    base_version && document.versions.last != base_version
  end

  def accept(user:)
    transaction do
      document.edit(body, user: user, summary: "Accepted agent suggestion: #{instruction.truncate(80)}")
      update!(status: "accepted")
    end
    score_acceptance(true)
  end

  def reject
    update!(status: "rejected")
    score_acceptance(false)
  end


  def diff
    Document::Diff.new(base_version&.body || "", body.to_s)
  end

  private

  # On the reviser's call: did the person take the suggested change?
  def score_acceptance(accepted)
    Langfuse::Score.record("oxybot-suggestion-#{id}-accepted", trace_id: trace_id, name: "suggestion_accepted", value: accepted)
  end
end
