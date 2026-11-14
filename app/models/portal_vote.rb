# A customer's vote on the portal. It is recorded as evidence like any other feedback: a note and an insight linked
# to the feature, with the voter's company, so the vote counts toward reach and ARR. Removing the vote removes both.
class PortalVote < ApplicationRecord
  belongs_to :account
  belongs_to :portal_visitor
  belongs_to :feature
  belongs_to :feedback_note, dependent: :destroy

  validates :feature_id, uniqueness: { scope: :portal_visitor_id }
  validate :feature_on_portal, on: :create

  def self.cast(visitor, feature)
    transaction do
      note = visitor.account.feedback_notes.create!(
        source: "portal", author_email: visitor.email, customer: visitor.customer, processed_at: Time.current, # nothing to extract
        body: "Voted for “#{feature.title}” on the customer portal."
      )
      note.insights.create!(account: visitor.account, product: feature.product, customer: visitor.customer, feature: feature,
                            triage_state: "linked", urgency: "medium", quote: "Voted for this on the customer portal.",
                            summary: "Wants #{feature.title}")
      create!(account: visitor.account, portal_visitor: visitor, feature: feature, feedback_note: note)
    end
  end

  private

  def feature_on_portal
    errors.add(:feature, "is not on the portal") unless feature&.on_portal && feature.account_id == account_id
  end
end
