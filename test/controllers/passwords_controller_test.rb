require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:kamil) }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create sends the mail from a job, so known and unknown addresses answer alike" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_redirected_to new_session_path
    assert_enqueued_with(job: SendPasswordResetJob)

    perform_enqueued_jobs(only: SendPasswordResetJob)
    assert_equal [ @user.email_address ], ActionMailer::Base.deliveries.last.to
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_redirected_to new_session_path

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      perform_enqueued_jobs(only: SendPasswordResetJob)
    end
  end

  test "the reset link carries its token in the query string, not the path" do
    get edit_password_path(token: @user.password_reset_token)
    assert_response :success
    assert_no_match @user.password_reset_token, request.path
  end

  test "edit with invalid password reset token" do
    get edit_password_path(token: "invalid token")
    assert_redirected_to new_password_path
  end

  test "update sets the password and ends sessions and the MCP token" do
    @user.sessions.create!
    @user.generate_mcp_token

    patch update_password_path(token: @user.password_reset_token), params: { password: "a-new-long-password", password_confirmation: "a-new-long-password" }

    assert_redirected_to new_session_path
    assert @user.reload.authenticate("a-new-long-password")
    assert_equal 0, @user.sessions.count
    assert_nil @user.mcp_token_digest
  end

  test "a short password is refused on every path, not only at sign-up" do
    token = @user.password_reset_token

    assert_no_changes -> { @user.reload.password_digest } do
      patch update_password_path(token: token), params: { password: "short", password_confirmation: "short" }
    end
    assert_response :unprocessable_entity
  end
end
