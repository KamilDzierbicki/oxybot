require "test_helper"

class FeaturePriorityTest < ActiveSupport::TestCase
  setup do
    @feature = features(:pdf_export)
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "x")
    [ customers(:northwind), customers(:northwind), customers(:contoso) ].each do |customer|
      note.insights.create!(account: accounts(:acme), product: products(:reports), customer: customer, quote: "q", summary: "s").link_to(@feature)
    end
  end

  test "RICE reach counts distinct customers from the evidence, not insights" do
    @feature.update!(impact: 2, confidence: 80, effort: 4)

    assert_equal 2, @feature.reach
    assert_equal 0.8, @feature.rice_score, "2 customers x 2 x 80% / 4 person-weeks"
    assert_equal 0.8, accounts(:acme).features.with_demand.find(@feature.id).rice_score, "the demand query gives the same reach"
  end

  test "no score until impact, confidence and effort are all set" do
    @feature.update!(impact: 2, confidence: nil, effort: 4)

    assert_nil @feature.rice_score
    assert_equal [ "confidence" ], @feature.rice_missing
  end

  test "values outside the RICE scales are refused" do
    @feature.assign_attributes(impact: 5, confidence: 70, effort: 0)

    assert_not @feature.valid?
    assert_equal %i[confidence effort impact], @feature.errors.attribute_names.sort
  end

  test "ordering by priority puts scored features first, highest score first" do
    @feature.update!(impact: 1, confidence: 100, effort: 1)
    other = features(:scheduled_reports).tap { |feature| feature.update!(impact: 3, confidence: 100, effort: 1) }
    unscored = features(:offline_mode)

    order = accounts(:acme).features.by_priority.map(&:id)

    assert_equal @feature.id, order.first, "2 customers x 1 beats 0 customers x 3"
    assert_operator order.index(other.id), :<, order.index(unscored.id), "a score of 0 still ranks above no score"
  end

  test "the assistant's feature list carries the priority, highest first" do
    @feature.update!(impact: 2, confidence: 100, effort: 1)

    turn = Data.define(:account, :revenue_visible?).new(account: accounts(:acme), revenue_visible?: true)
    listed = ListFeaturesTool.new(turn).execute[:features]

    assert_equal [ @feature.id, 4.0, 2 ], listed.first.values_at(:id, :rice, :reach_customers)
  end
end
