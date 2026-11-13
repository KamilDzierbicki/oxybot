class Contact < ApplicationRecord
  belongs_to :account
  belongs_to :customer, optional: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: { scope: :account_id }
end
