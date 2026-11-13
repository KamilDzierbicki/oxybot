# A tenant: one company using OxyBot. Every other record belongs to exactly one account.
class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :features, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :feedback_notes, dependent: :destroy
  has_many :insights, dependent: :destroy
  has_many :knowledge_documents, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_one :slack_integration, class_name: "Integration::Slack"
  has_one :hubspot_integration, class_name: "Integration::Hubspot"

  validates :name, presence: true
end
