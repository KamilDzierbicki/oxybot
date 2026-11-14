# A customer of the tenant, usually synced from HubSpot. ARR is what makes a feature request weigh more.
class Customer < ApplicationRecord
  belongs_to :account
  has_many :contacts, dependent: :nullify
  has_many :feedback_notes, dependent: :nullify
  has_many :insights, dependent: :nullify
  has_many :portal_visitors, dependent: :nullify

  normalizes :domain, with: ->(domain) { domain.strip.downcase.delete_prefix("www.").presence }

  validates :name, presence: true

  scope :by_arr, -> { order(arr_cents: :desc, name: :asc) }

  def self.named(name)
    find_by("lower(name) = ?", name.to_s.strip.downcase) if name.present?
  end

  def arr = arr_cents / 100
end
