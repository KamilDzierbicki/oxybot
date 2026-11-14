# A backlog item of one product. Insights link to it, and its demand (insights, customers, their ARR) ranks it.
class Feature < ApplicationRecord
  include Embeddable, HybridSearchable, Deliverable, Prioritizable

  STATUSES = %w[idea planned in_progress released].freeze

  belongs_to :account
  belongs_to :product
  has_many :insights, dependent: :nullify
  has_many :suggested_insights, class_name: "Insight", foreign_key: :suggested_feature_id, dependent: :nullify
  has_many :documents, dependent: :nullify

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :product_in_same_account

  after_save_commit :embed_later, if: -> { saved_change_to_title? || saved_change_to_description? }
  # Needs that found no feature before get another look once the backlog grows
  after_create_commit -> { product.insights.pending.where(suggested_feature_id: nil).find_each(&:match_later) }

  # Insight count, distinct customers and their ARR, each customer counted once per feature
  scope :with_demand, -> {
    select(<<~SQL.squish)
      features.*,
      (SELECT COUNT(*) FROM insights WHERE insights.feature_id = features.id) AS insight_count,
      (SELECT COUNT(DISTINCT customer_id) FROM insights WHERE insights.feature_id = features.id) AS customer_count,
      (SELECT COALESCE(SUM(customers.arr_cents), 0) FROM customers WHERE customers.id IN
        (SELECT customer_id FROM insights WHERE insights.feature_id = features.id)) AS demand_arr_cents,
      (SELECT COUNT(DISTINCT customer_id) FROM insights WHERE insights.feature_id = features.id)
        * features.impact * features.confidence / 100.0 / NULLIF(features.effort, 0) AS rice_sort
    SQL
  }
  scope :by_demand, -> { with_demand.order("demand_arr_cents DESC, insight_count DESC, features.title ASC, features.id ASC") }
  # Unscored features last, then demand breaks ties
  scope :by_priority, -> { with_demand.order(Arel.sql("rice_sort DESC NULLS LAST, demand_arr_cents DESC, features.title ASC, features.id ASC")) }

  def embedding_text = "#{title}\n#{description}"

  def embed_later
    EmbedJob.perform_later(self)
  end

  private

  def product_in_same_account
    errors.add(:product, "belongs to another account") if product && product.account_id != account_id
  end
end
