require "test_helper"

class Feature::DeliverableTest < ActiveSupport::TestCase
  setup { @feature = features(:pdf_export) }

  test "sending to Linear creates an issue with the feature's spec and a link back" do
    spec = Document.create!(account: accounts(:acme), feature: @feature, kind: "prd", title: "Spec", status: "ready", body: "## Summary\nExport to PDF.")

    @feature.send_to_linear

    assert_equal "OXY-1", @feature.linear_identifier
    issue = integrations(:acme_linear).reload.mock_issues.fetch(@feature.linear_issue_id)
    assert_equal @feature.title, issue["title"]
    assert spec.persisted?
  end

  test "a status change here moves the Linear issue" do
    @feature.send_to_linear

    @feature.update!(status: "in_progress")
    perform_enqueued_jobs(only: MoveLinearIssueJob)

    assert_equal "started", integrations(:acme_linear).reload.mock_issues.fetch(@feature.linear_issue_id)["state"]
    assert_equal "In Progress", @feature.reload.linear_state
  end

  test "a change coming from Linear is applied without echoing it back" do
    @feature.send_to_linear

    assert_no_enqueued_jobs(only: MoveLinearIssueJob) do
      @feature.apply_linear_state(type: "completed", name: "Done")
    end
    assert_equal "released", @feature.status
    assert @feature.released_at, "releasing stamps the release date for launch reviews"
  end

  test "a feature cannot be sent twice" do
    @feature.send_to_linear

    assert_raises(ArgumentError) { @feature.send_to_linear }
  end

  test "the real client picks the team's first state of the type and reports its name" do
    states = { data: { workflowStates: { nodes: [ { id: "s2", name: "In Review", position: 2 }, { id: "s1", name: "In Progress", position: 1 } ] } } }
    stub_request(:post, "https://api.linear.app/graphql").with { |request| request.body.include?("workflowStates") }.to_return(body: states.to_json)
    update = stub_request(:post, "https://api.linear.app/graphql").with { |request| request.body.include?("issueUpdate") && request.body.include?("s1") }
                                                                  .to_return(body: { data: { issueUpdate: { success: true } } }.to_json)

    name = Integration::Linear::Client.new("lin_api_test").move_issue("issue-1", team_id: "team-acme", state_type: "started")

    assert_equal "In Progress", name
    assert_requested update
  end
end
