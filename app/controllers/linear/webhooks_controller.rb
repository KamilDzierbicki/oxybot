# Linear webhook: verified with the integration's signing secret (hex HMAC-SHA256 of the raw body in
# Linear-Signature) and refused when webhookTimestamp is more than a minute old, as Linear recommends.
class Linear::WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    payload = JSON.parse(request.raw_post)
    return head :bad_request unless payload.is_a?(Hash)

    integration = Integration::Linear.find_by(external_id: payload["organizationId"])
    return head :unauthorized unless integration && valid_signature?(integration) && fresh?(payload)

    integration.receive(payload)
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def valid_signature?(integration)
    return false if integration.webhook_secret.blank?

    expected = OpenSSL::HMAC.hexdigest("SHA256", integration.webhook_secret, request.raw_post)
    ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["Linear-Signature"].to_s)
  end

  def fresh?(payload)
    (Time.current.to_f * 1000 - payload["webhookTimestamp"].to_f).abs < 60_000
  end
end
