class Product < ApplicationRecord
  belongs_to :account
  has_many :features, dependent: :destroy
  has_many :insights, dependent: :destroy

  # Non-Latin names (Hebrew, Arabic) transliterate to nothing; they get a generated slug instead of an error
  normalizes :slug, with: ->(slug) { slug.strip.downcase.parameterize.presence || "product-#{SecureRandom.hex(3)}" }

  # A blank slug field means "use the name"; it is dropped before normalizes would turn it into a random slug
  def slug=(value)
    super(value.presence)
  end

  before_validation { self.slug = name if slug.blank? && name.present? }

  validates :name, :description, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }

  scope :alphabetically, -> { order(:name, :id) }

  # Feedback that arrived before the workspace had any product waited unprocessed; it can be split now
  after_create_commit -> { account.feedback_notes.where(processed_at: nil).find_each(&:extract_insights_later) }

  def to_param = slug
end
