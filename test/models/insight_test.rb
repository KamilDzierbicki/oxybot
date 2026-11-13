require "test_helper"

class InsightTest < ActiveSupport::TestCase
  setup do
    embed_features
    @note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
  end

  test "suggests the feature that solves the need, but does not link it" do
    insight = create_insight("Export weekly reports to PDF for the board", product: products(:reports))

    insight.match

    assert_equal features(:pdf_export), insight.suggested_feature
    assert insight.pending?, "a PM confirms the suggestion; matching never links on its own"
    assert_nil insight.feature
  end

  test "suggests nothing when no feature fits" do
    insight = create_insight("Dark theme for charts in reports would look nicer", product: products(:reports))

    insight.match

    assert_nil insight.suggested_feature
  end

  test "only features of the insight's product are candidates" do
    insight = create_insight("Open dashboards offline without internet", product: products(:reports))

    insight.match

    assert_not_equal features(:offline_mode), insight.suggested_feature, "offline mode belongs to the mobile product"
  end

  test "search stays inside the account" do
    acme = create_insight("PDF export of reports for finance", product: products(:reports))
    globex_note = accounts(:globex).feedback_notes.create!(source: "manual", body: "placeholder")
    globex = globex_note.insights.create!(account: accounts(:globex), product: products(:billing), quote: "PDF export of invoices", summary: "PDF export of invoices")
    [acme, globex].each(&:embed)

    results = accounts(:acme).insights.hybrid_search("PDF export")

    assert_includes results, acme
    assert_not_includes results, globex
  end

  test "linking to a feature of another product is refused" do
    insight = create_insight("Export reports to PDF", product: products(:reports))

    assert_raises(ActiveRecord::RecordInvalid) { insight.link_to(features(:offline_mode)) }
  end

  private

  def create_insight(summary, product:)
    @note.insights.create!(account: accounts(:acme), product: product, quote: summary, summary: summary)
  end
end
