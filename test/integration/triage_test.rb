require "test_helper"

class TriageTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:kamil)
    note = accounts(:acme).feedback_notes.create!(source: "manual", body: "placeholder")
    @insight = note.insights.create!(account: accounts(:acme), product: products(:reports), quote: "PDF export please",
                                     summary: "PDF export of reports", suggested_feature: features(:pdf_export))
  end

  test "linking a suggestion moves the insight out of the inbox and counts toward demand" do
    post insight_link_path(@insight), params: { feature_id: features(:pdf_export).id }

    assert @insight.reload.linked?
    get features_path
    assert_select "td", text: "PDF export of reports"
  end

  test "an insight of another tenant cannot be triaged" do
    other = accounts(:globex).feedback_notes.create!(source: "manual", body: "x")
                             .insights.create!(account: accounts(:globex), product: products(:billing), quote: "q", summary: "s")

    post insight_dismissal_path(other)

    assert_response :not_found
    assert other.reload.pending?
  end

  test "a feature from another product cannot be linked" do
    post insight_link_path(@insight), params: { feature_id: features(:offline_mode).id }

    assert_response :not_found
    assert @insight.reload.pending?
  end

  test "a new feature can be created from an insight" do
    assert_difference -> { products(:reports).features.count }, 1 do
      post insight_feature_path(@insight)
    end
    assert_equal "PDF export of reports", @insight.reload.feature.title
  end

  test "pages render for a signed-in user" do
    [ conversations_path, insights_path, features_path, feedback_notes_path, customers_path, knowledge_documents_path, integrations_path,
     integration_path(integrations(:acme_slack)), integration_path(integrations(:acme_hubspot)) ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "another tenant's conversation is not reachable" do
    conversation = accounts(:globex).conversations.create!(user: users(:eve))

    get conversation_path(conversation)

    assert_response :not_found
  end
end
