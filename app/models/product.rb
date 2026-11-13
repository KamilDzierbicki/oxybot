class Product < ApplicationRecord
  belongs_to :account
  has_many :features, dependent: :destroy
  has_many :insights, dependent: :destroy

  # Non-Latin names (Hebrew, Arabic) transliterate to nothing; they get a generated slug instead of an error
  normalizes :slug, with: ->(slug) { slug.strip.downcase.parameterize.presence || "product-#{SecureRandom.hex(3)}" }

  validates :name, :description, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }

  scope :alphabetically, -> { order(:name, :id) }

  def to_param = slug
end
