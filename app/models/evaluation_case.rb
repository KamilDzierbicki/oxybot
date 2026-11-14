# A case for the evaluation datasets that came from a person's correction. It waits for review: an approved case
# joins the matching experiments next to config/evals/matching.yml. Its input is customer text, so it reaches
# Langfuse only when traces may carry content (OXYBOT_TRACE_CONTENT).
class EvaluationCase < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :account
  belongs_to :insight, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :task, inclusion: { in: Evaluation::TASKS }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }

  # The judge suggested another feature (or none) than the one the person linked
  def self.record_matching_correction(insight)
    case_for = find_or_initialize_by(insight: insight, task: "matching")
    return if case_for.persisted? && !case_for.pending? # a reviewed case keeps its decision

    case_for.update!(account: insight.account, input: { "product" => insight.product.slug, "input" => insight.summary },
                     expected: { "feature" => insight.feature.title, "suggested" => insight.suggested_feature&.title })
  end

  def pending? = status == "pending"

  def review(status, by:) = update!(status: status, reviewed_by: by)

  # The shape of config/evals/matching.yml, marked private so its text stays out of Langfuse unless content is allowed
  def to_item = input.merge("id" => "case-#{id}", "expected" => expected.slice("feature"), "private" => true)
end
