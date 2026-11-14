# Raw feedback as it arrived (a Slack message, a form, a HubSpot note). The extractor splits it into insights.
class FeedbackNote < ApplicationRecord
  include Extractable

  SOURCES = %w[manual slack mattermost hubspot email portal intercom zendesk gong].freeze

  belongs_to :account
  belongs_to :customer, optional: true
  has_many :insights, dependent: :destroy
  has_one :portal_vote, dependent: :delete # deleting a vote's note takes the vote with it

  broadcasts_refreshes

  normalizes :author_email, with: ->(email) { email.strip.downcase.presence }
  normalizes :body, :author, with: ->(text) { VisibleText.clean(text) }

  validates :body, presence: true
  validates :source, inclusion: { in: SOURCES }

  before_validation :resolve_customer, on: :create

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def processed? = processed_at.present?

  private

  # A known contact wins; otherwise the email's domain (jan@acme.com -> acme.com) picks the company.
  def resolve_customer
    return if customer || author_email.blank?

    self.customer = account.customer_for_email(author_email)
  end
end
