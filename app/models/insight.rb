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

  def link_to(feature)
    update!(feature: feature, triage_state: "linked")
  end

  def dismiss
    update!(feature: nil, triage_state: "dismissed")
  end

  def restore
    update!(feature: nil, triage_state: "pending")
  end

  private

  def feature_in_same_product
    errors.add(:feature, "belongs to another product") if feature && feature.product_id != product_id
  end
end
