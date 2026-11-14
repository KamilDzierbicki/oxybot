require "test_helper"

class RoadmapTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:kamil) }

  test "a feature moves between lanes and off the roadmap, and lanes order by priority" do
    low = features(:scheduled_reports).tap { |feature| feature.update!(roadmap_lane: "next", impact: 0.25, confidence: 50, effort: 10) }
    high = features(:pdf_export).tap { |feature| feature.update!(impact: 2, confidence: 100, effort: 1) }
    accounts(:acme).feedback_notes.create!(source: "manual", body: "x").insights
                   .create!(account: accounts(:acme), product: products(:reports), customer: customers(:northwind), quote: "q", summary: "s").link_to(high)

    patch feature_roadmap_placement_path(high), params: { roadmap_lane: "next" }
    get roadmap_path
    lane = css_select("#lane-next").first.parent
    assert_equal [ high.title, low.title ], lane.css(".roadmap__feature").map(&:text), "1 customer x 2 / 1 week beats no customers"

    patch feature_roadmap_placement_path(high), params: { roadmap_lane: "" }
    assert_nil high.reload.roadmap_lane
  end

  test "a lane outside Now, Next and Later is refused" do
    patch feature_roadmap_placement_path(features(:pdf_export)), params: { roadmap_lane: "someday" }

    assert_nil features(:pdf_export).reload.roadmap_lane
    assert_equal "Roadmap lane is not included in the list", flash[:alert]
  end

  test "the portal switch is separate from the lane" do
    patch feature_roadmap_placement_path(features(:pdf_export)), params: { on_portal: "1" }

    assert features(:pdf_export).reload.on_portal
  end

  test "another workspace's feature cannot be placed" do
    patch feature_roadmap_placement_path(features(:invoice_pdf)), params: { roadmap_lane: "now" }

    assert_response :not_found
  end
end
