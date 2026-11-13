# The Slack simulator: builds the same event Slack's Events API would send and hands it to the integration,
# so feedback channels, mentions and threaded replies can be tried without a Slack app.
class Integrations::SimulatedMessagesController < ApplicationController
  def create
    integration = Current.account.integrations.where(type: "Integration::Slack").find(params[:integration_id])
    integration.receive(event_for(integration))
    redirect_to integration
  end

  private

  def event_for(integration)
    message = params.expect(simulated_message: %i[channel_id text slack_user_id thread_ts mention])
    text = message[:text]
    text = "<@#{integration.app_user_id}> #{text}" if message[:mention] == "1"

    { "type" => text.include?("<@#{integration.app_user_id}>") ? "app_mention" : "message",
      "channel" => message[:channel_id], "channel_type" => message[:channel_id].start_with?("D") ? "im" : "channel",
      "user" => message[:slack_user_id], "text" => text, "ts" => format("%.6f", Time.current.to_f),
      "thread_ts" => message[:thread_ts].presence }.compact
  end
end
