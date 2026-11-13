require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup { Current.session = users(:kamil).sessions.create! }

  test "a list right after a sentence renders as a list, not as literal dashes" do
    assert_includes markdown("Top requests:\n- PDF export\n- SSO"), "<li>PDF export</li>"
  end

  test "a citation previews its quote and customer, but only for this workspace's insights" do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "x", customer: customers(:northwind))
    own = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "Board wants PDFs", summary: "PDF",
                                customer: customers(:northwind))
    foreign = accounts(:globex).feedback_notes.create!(source: "manual", body: "y")
                               .insights.create!(account: accounts(:globex), product: products(:billing), quote: "Secret plan", summary: "s")

    html = markdown("Needed [insight:#{own.id}] and [insight:#{foreign.id}]")

    assert_includes html, "Board wants PDFs"
    assert_includes html, customers(:northwind).name
    assert_not_includes html, "Secret plan"
  end
end
