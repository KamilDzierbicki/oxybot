# A tenant: one company using OpenSpark. Every other record belongs to exactly one account.
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
  has_many :documents, dependent: :destroy
  has_many :document_templates, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_one :slack_integration, class_name: "Integration::Slack"
  has_one :hubspot_integration, class_name: "Integration::Hubspot"
  has_one :linear_integration, class_name: "Integration::Linear"
  has_one :github_integration, class_name: "Integration::Github"

  validates :name, presence: true

  after_create_commit -> { DocumentTemplate.install_defaults(self) }

  # The weekly opportunity report (config/recurring.yml); it is posted to Slack when it is ready
  def discover_opportunities
    Document.draft(account: self, kind: "opportunity_report")
  end
end
