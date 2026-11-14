require "test_helper"

class TeamManagementTest < ActionDispatch::IntegrationTest
  test "members cannot change integrations, users, AI settings or team instructions" do
    sign_in_as users(:mia)

    patch integration_path(integrations(:acme_slack)), params: { integration: { feedback_channel_ids: "C_X" } }
    assert_response :forbidden
    get users_path
    assert_response :forbidden
    patch ai_settings_path, params: { account: { agent_max_rounds: "2" } }
    assert_response :forbidden
    patch team_instructions_path, params: { account: { custom_instructions: "x" } }
    assert_response :forbidden
    assert_equal [ "C_FEEDBACK" ], integrations(:acme_slack).reload.feedback_channel_ids
  end

  test "members still use the product" do
    sign_in_as users(:mia)

    [ insights_path, features_path, documents_path, integrations_path, skills_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "an admin invites a colleague who joins the same account" do
    sign_in_as users(:kamil)
    post invitations_path, params: { invitation: { email: "new.pm@acme.example", role: "member" } }
    url = flash[:invitation_url]
    sign_out

    get url
    assert_response :success
    post url, params: { user: { name: "New PM", password: "long-enough-password" } }

    user = User.find_by!(email_address: "new.pm@acme.example")
    assert_equal accounts(:acme), user.account
    assert_equal "member", user.role
    get url
    assert_response :not_found, "an invitation works once"
  end

  test "an expired invitation cannot be used" do
    invitation = accounts(:acme).invitations.create!(email: "late@acme.example", invited_by: users(:kamil))
    invitation.update_columns(expires_at: 1.minute.ago)

    get invitation_acceptance_path(token: invitation.token)

    assert_response :not_found
  end

  test "the last admin cannot be demoted" do
    sign_in_as users(:kamil)

    patch user_path(users(:kamil)), params: { user: { role: "member" } }

    assert users(:kamil).reload.admin?
  end

  test "signing up creates an account with its admin and default templates" do
    post signup_path, params: { signup: { account_name: "Initech", name: "Peter", email_address: "peter@initech.example", password: "long-enough-password" } }

    user = User.find_by!(email_address: "peter@initech.example")
    assert user.admin?
    assert_equal Document::KINDS.size, user.account.document_templates.count
    assert_redirected_to root_path
  end

  test "an admin connects an integration in mock mode and checks it" do
    sign_in_as users(:eve)

    post integrations_path, params: { integration: { kind: "linear", external_id: "org-globex", team_id: "team-g" } }
    linear = accounts(:globex).linear_integration
    assert linear.mock?

    post integration_connection_check_path(linear)
    assert linear.reload.last_check_ok
  end

  test "a Slack connection check catches a token from another workspace and learns the bot id" do
    slack = integrations(:acme_slack)
    slack.update!(access_token: "xoxb-test", app_user_id: nil)
    stub_request(:post, "https://slack.com/api/auth.test").to_return(body: { ok: true, team_id: "T_ACME", team: "Acme", user: "oxybot", user_id: "U_BOT" }.to_json)

    ok, _message = slack.check_connection
    assert ok
    assert_equal "U_BOT", slack.reload.app_user_id

    stub_request(:post, "https://slack.com/api/auth.test").to_return(body: { ok: true, team_id: "T_OTHER", user_id: "U_BOT" }.to_json)
    ok, message = slack.check_connection
    assert_not ok
    assert_match "T_OTHER", message
  end
end
