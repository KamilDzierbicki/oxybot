# Mattermost slash command (/oxybot ...). The token comes as "Authorization: Token ..." (and in the body).
# Mattermost waits a few seconds for an answer, so it gets an acknowledgement now and the real answer later
# through the command's response_url.
class Mattermost::CommandsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    integration = Integration::Mattermost.find_by(external_id: params[:team_id])
    token = request.authorization.to_s.delete_prefix("Token ").presence || params[:token].presence
    token = nil unless token.is_a?(String)
    return head :unauthorized unless integration&.valid_command_token?(token)

    integration.receive_command(params.permit(:channel_id, :user_id, :text, :trigger_id, :response_url).to_h)
    render json: { response_type: "ephemeral", text: "Looking through your feedback…" }
  end
end
