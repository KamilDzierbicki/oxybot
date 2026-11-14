# One customer need taken from a feedback note, the unit a PM triages and links to a feature.
class Insight < ApplicationRecord
  include Embeddable, HybridSearchable, Matchable

  TRIAGE_STATES = %w[pending linked dismissed].freeze
  URGENCIES = %w[low medium high].freeze

  belongs_to :account
  belongs_to :feedback_note
  belongs_to :product
  belongs_to :customer, optional: true
  belongs_to :feature, optional: true
  belongs_to :suggested_feature, class_name: "Feature", optional: true

  validates :quote, :summary, presence: true
  validates :triage_state, inclusion: { in: TRIAGE_STATES }
  validates :urgency, inclusion: { in: URGENCIES }
  validate :feature_in_same_product

  scope :pending, -> { where(triage_state: "pending") }
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def embedding_text = "#{summary}\n#{quote}"

  def pending? = triage_state == "pending"
  def linked? = triage_state == "linked"
  def dismissed? = triage_state == "dismissed"

  # created: the person made a new feature for it, which is right when the judge found no existing one
  def link_to(feature, created: false)
    update!(feature: feature, triage_state: "linked")
    score_match(feature == suggested_feature || (created && suggested_feature.nil?))
    score_kept(true)
  end

  def dismiss
    update!(feature: nil, triage_state: "dismissed")
    Langfuse::Score.remove(score_id("feature-match"))
    score_kept(false)
  end

  def restore
    update!(feature: nil, triage_state: "pending")
    Langfuse::Score.remove(score_id("feature-match"))
    Langfuse::Score.remove(score_id("kept"))
  end

  private

  # On the judge's call: did it suggest the feature the person chose?
  def score_match(correct)
    Langfuse::Score.record(score_id("feature-match"), trace_id: match_trace_id, name: "feature_match", value: correct)
  end

  # On the extraction call of the note: was this a real customer need?
  def score_kept(kept)
    Langfuse::Score.record(score_id("kept"), trace_id: feedback_note.extraction_trace_id, name: "insight_kept", value: kept)
  end

  def score_id(name) = "oxybot-insight-#{id}-#{name}"

  def feature_in_same_product
    errors.add(:feature, "belongs to another product") if feature && feature.product_id != product_id
  end
end
