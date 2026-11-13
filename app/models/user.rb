class User < ApplicationRecord
  has_secure_password
  belongs_to :account
  has_many :sessions, dependent: :destroy
  has_many :conversations, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :slack_user_id, with: ->(id) { id.strip.presence }

  validates :name, presence: true
end
