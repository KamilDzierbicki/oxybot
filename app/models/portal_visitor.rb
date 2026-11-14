# Someone who signed in to a workspace's customer portal with a link sent to their email. The email's company
# (a known contact, or the domain) links their votes to a customer, so votes count toward demand and ARR.
class PortalVisitor < ApplicationRecord
  belongs_to :account
  belongs_to :customer, optional: true
  has_many :portal_votes, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :account_id }

  before_validation -> { self.customer ||= account&.customer_for_email(email) }

  # Single use: signing in changes last_signed_in_at, which invalidates every earlier link
  generates_token_for :sign_in, expires_in: 20.minutes do
    last_signed_in_at
  end

  def voted_for?(feature) = portal_votes.any? { |vote| vote.feature_id == feature.id }
end
