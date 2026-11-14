# A tenant: one company using OxyBot. Every other record belongs to exactly one account.
class Account < ApplicationRecord
  include AiSettings

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
  has_many :invitations, dependent: :destroy
  has_one :slack_integration, class_name: "Integration::Slack"
  has_one :mattermost_integration, class_name: "Integration::Mattermost"
  has_one :hubspot_integration, class_name: "Integration::Hubspot"
  has_one :linear_integration, class_name: "Integration::Linear"
  has_one :github_integration, class_name: "Integration::Github"

  validates :name, presence: true

  after_create_commit -> { DocumentTemplate.install_defaults(self) }

  EXPORTED = {
    users: %i[id name email_address role slack_user_id mattermost_user_id created_at],
    products: %i[id name slug description], features: %i[id product_id title description status released_at linear_identifier],
    customers: %i[id name domain plan arr_cents], contacts: %i[id customer_id email name],
    feedback_notes: %i[id customer_id source author author_email body created_at],
    insights: %i[id feedback_note_id product_id customer_id feature_id quote summary urgency triage_state created_at],
    documents: %i[id feature_id kind title body status created_at updated_at],
    knowledge_documents: %i[id title body], skills: %i[id user_id name description instructions],
    conversations: %i[id user_id channel title created_at]
  }.freeze

  def export
    EXPORTED.to_h { |association, columns| [ association, public_send(association).order(:id).map { |record| record.slice(*columns) } ] }
            .merge(account: slice(:id, :name, :time_zone, :custom_instructions, :created_at),
                   messages: Message.joins(:conversation).where(conversations: { account_id: id }).order(:id).map { |message| message.slice(:id, :conversation_id, :role, :content, :created_at) })
  end

  # The weekly opportunity report (config/recurring.yml); it is posted to Slack when it is ready
  def stale_embeddings?
    features.stale_embeddings.exists? || insights.stale_embeddings.exists?
  end

  def discover_opportunities
    Document.draft(account: self, kind: "opportunity_report")
  end
end
