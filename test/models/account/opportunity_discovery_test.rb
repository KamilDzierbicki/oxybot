require "test_helper"

class Account::OpportunityDiscoveryTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @note = @account.feedback_notes.create!(source: "manual", body: "placeholder")
  end

  test "growth compares this week's linked insights with the week before" do
    travel_to(10.days.ago) do
      insight("PDF before", feature: features(:pdf_export))
    end
    3.times { |i| insight("PDF now #{i}", feature: features(:pdf_export)) }

    row = discovery.growing_features.first

    assert_equal features(:pdf_export), row[:feature]
    assert_equal [ 3, 1, 2 ], row.values_at(:this_week, :last_week, :growth)
  end

  test "similar needs without a feature form an emerging theme; a lone need does not" do
    a = insight("Dark mode for dashboards at night", customer: customers(:northwind))
    b = insight("Dark mode for dashboards in the evening", customer: customers(:contoso))
    lone = insight("Invoices in Norwegian kroner")
    [ a, b, lone ].each(&:embed)

    themes = discovery.emerging_themes

    assert_equal [ [ a, b ].sort_by(&:id) ], themes.map { |members| members.sort_by(&:id) }
  end

  test "a customer's ARR counts once per feature and plan, even with many insights" do
    2.times { insight("PDF again", feature: features(:pdf_export), customer: customers(:northwind)) }
    insight("PDF from contoso", feature: features(:pdf_export), customer: customers(:contoso))

    plans = discovery.segments.find { |row| row[:feature] == features(:pdf_export) }[:plans].index_by { |plan| plan[:plan] }

    assert_equal 1, plans["Enterprise"][:customers]
    assert_equal customers(:northwind).arr_cents, plans["Enterprise"][:arr_cents]
    assert_equal customers(:contoso).arr_cents, plans["Growth"][:arr_cents]
  end

  test "the roadmap check flags demand still parked as an idea and planned work nobody asked for" do
    insight("Weekly email please", feature: features(:scheduled_reports), customer: customers(:contoso))

    gaps = discovery.roadmap_gaps

    assert_includes gaps[:underserved], features(:scheduled_reports)
    assert_includes gaps[:unasked].map(&:title), "PDF export of reports"
  end

  private

  def discovery = Account::OpportunityDiscovery.new(@account)

  def insight(summary, feature: nil, customer: nil)
    record = @note.insights.create!(account: @account, product: feature&.product || products(:reports), customer: customer, quote: summary, summary: summary)
    record.link_to(feature) if feature
    record
  end
end
