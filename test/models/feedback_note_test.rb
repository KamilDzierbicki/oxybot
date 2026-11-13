require "test_helper"

class FeedbackNoteTest < ActiveSupport::TestCase
  setup { @account = accounts(:acme) }

  test "splits one message into insights per product, skipping small talk" do
    note = @account.feedback_notes.create!(source: "manual", author_email: "anna@northwind.example", body: <<~TEXT)
      Hi team!
      We really need to export our weekly reports to PDF for the board meeting.
      The mobile app cannot open dashboards offline on the plane, which blocks our drivers.
    TEXT

    note.extract_insights

    insights = note.insights.order(:id)
    assert_equal %w[reports mobile], insights.map { |insight| insight.product.slug }
    assert_equal "high", insights.last.urgency, "a blocking problem must be marked urgent"
    assert insights.all? { |insight| insight.customer == customers(:northwind) }, "the contact's company is the customer"
    assert note.processed?
  end

  test "a retried job does not create the insights twice" do
    note = @account.feedback_notes.create!(source: "manual", body: "Please add PDF export of reports for our finance team.")

    2.times { note.extract_insights }

    assert_equal 1, note.insights.count
  end

  test "an unknown email domain leaves the note without a customer" do
    note = @account.feedback_notes.create!(source: "manual", author_email: "someone@unknown.example", body: "Reports are slow to load today again.")

    assert_nil note.customer
  end

  test "the email domain finds the customer when the contact is unknown" do
    note = @account.feedback_notes.create!(source: "manual", author_email: "new.person@contoso.example", body: "Reports need PDF export please.")

    assert_equal customers(:contoso), note.customer
  end

  test "another tenant's customer with the same domain is never matched" do
    note = accounts(:globex).feedback_notes.create!(source: "manual", author_email: "x@northwind.example", body: "Invoices need PDF export.")

    assert_nil note.customer
  end

  test "an insight for a product the model invented is dropped" do
    note = @account.feedback_notes.create!(source: "manual", body: "placeholder")
    insight = note.send(:build_insight, { "product_slug" => "billing", "quote" => "Invoices are wrong.", "summary" => "Wrong invoices" })

    assert_nil insight, "billing belongs to another account, so the extractor may not use it"
  end
end
