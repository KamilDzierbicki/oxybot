class Product < ApplicationRecord
  belongs_to :account
  has_many :features, dependent: :destroy
  has_many :insights, dependent: :destroy

  normalizes :slug, with: ->(slug) { slug.strip.downcase.parameterize }

  validates :name, :description, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }

  scope :alphabetically, -> { order(:name) }

  def to_param = slug
end
