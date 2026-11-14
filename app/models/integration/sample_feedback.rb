# Feedback for source integrations in test mode: a few fixed conversations, so the whole path (sync, extraction,
# triage) can be tried without an account. Ids are stable, so syncing again imports nothing new.
class Integration::SampleFeedback
  ITEMS = [
    { external_id: "sample-1", author: "Priya Shah", author_email: "priya@fabrikam.example",
      body: "Our auditors keep asking for the monthly report as a PDF. Can we schedule that export?" },
    { external_id: "sample-2", author: "Mark Lee", author_email: "mark@contoso.example",
      body: "The Shopify sync stopped again over the weekend and we lost two days of orders in the dashboard." }
  ].freeze

  def initialize(kind) = @kind = kind

  def feedback_since(_time) = ITEMS.map { |item| item.merge(external_id: "#{@kind}-#{item[:external_id]}", created_at: Time.current) }
end
