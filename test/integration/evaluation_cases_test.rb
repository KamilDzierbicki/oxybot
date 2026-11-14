require "test_helper"

class EvaluationCasesTest < ActionDispatch::IntegrationTest
  setup do
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    insight = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "q", summary: "Weekly report by email",
                                    suggested_feature: features(:pdf_export), match_reason: "judged")
    insight.link_to(features(:scheduled_reports))
    @case = EvaluationCase.last
  end

  test "an admin approves a correction from the review page" do
    sign_in_as users(:kamil)
    get evaluation_cases_path
    assert_select "td", text: /Weekly report by email/

    patch evaluation_case_path(@case), params: { status: "approved" }

    assert_equal [ "approved", users(:kamil) ], [ @case.reload.status, @case.reviewed_by ]
  end

  test "members cannot review cases" do
    sign_in_as users(:mia)

    patch evaluation_case_path(@case), params: { status: "approved" }

    assert @case.reload.pending?
  end
end
