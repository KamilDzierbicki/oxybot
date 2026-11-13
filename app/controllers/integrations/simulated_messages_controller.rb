# The chat simulator (mock mode): hands a message to the integration the way its platform adapter would, so
# feedback channels, mentions, direct messages and threaded replies can be tried without a real workspace.
class Integrations::SimulatedMessagesController < ApplicationController
  admin_only
  def create
    integration = Current.account.integrations.find(params[:integration_id])
    return head :not_found unless integration.chat? && integration.mock?

    message = params.expect(simulated_message: %i[channel_id text user_id mention])
    integration.receive_message(channel_id: message[:channel_id], message_id: "sim-#{SecureRandom.hex(6)}", user_id: message[:user_id],
                                text: message[:text], private: message[:channel_id] == "DIRECT", mentions_app: message[:mention] == "1")
    redirect_to integration
  end
end
