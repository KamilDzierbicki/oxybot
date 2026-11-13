# Mattermost outgoing webhooks (feedback channels and @oxybot questions). Mattermost puts the webhook's token in
# the payload; a request without a token saved on the team's integration is refused.
class Mattermost::WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    payload = request.request_parameters.presence || JSON.parse(request.raw_post.presence || "{}")
    integration = Integration::Mattermost.find_by(external_id: payload["team_id"])
    return head :unauthorized unless integration&.valid_webhook_token?(payload["token"])

    integration.receive_webhook(payload)
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
