require "test_helper"

class Linear::WebhooksControllerTest < ActionDispatch::IntegrationTest
  SECRET = "lin_wh_test_secret"

  setup do
    integrations(:acme_linear).update!(webhook_secret: SECRET)
    @feature = features(:pdf_export)
    @feature.update_columns(linear_issue_id: "issue-1", linear_identifier: "OXY-1")
  end

  test "a signed issue update moves the feature" do
    post_webhook(payload(state_type: "started"))

    assert_response :ok
    assert_equal "in_progress", @feature.reload.status
  end

  test "a wrong signature is refused" do
    post_webhook(payload(state_type: "completed"), signature: "0" * 64)

    assert_response :unauthorized
    assert_equal "planned", @feature.reload.status
  end

  test "a replayed delivery older than a minute is refused" do
    post_webhook(payload(state_type: "completed", sent_at: 5.minutes.ago))

    assert_response :unauthorized
  end

  test "a delivery for another organization never touches this account" do
    post_webhook(payload(state_type: "completed").merge(organizationId: "org-other"))

    assert_response :unauthorized
    assert_equal "planned", @feature.reload.status
  end

  private

  def payload(state_type:, sent_at: Time.current)
    { type: "Issue", action: "update", organizationId: "org-acme", webhookTimestamp: (sent_at.to_f * 1000).to_i,
      data: { id: "issue-1", identifier: "OXY-1", state: { type: state_type, name: state_type.humanize } } }
  end

  def post_webhook(payload, signature: nil)
    body = payload.to_json
    post linear_webhooks_path, params: body, headers: { "Content-Type" => "application/json",
                                                        "Linear-Signature" => signature || OpenSSL::HMAC.hexdigest("SHA256", SECRET, body) }
  end
end
