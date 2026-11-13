# The few Slack Web API calls OpenSpark needs, over plain HTTPS.
class Integration::Slack::Client
  BASE_URL = "https://slack.com/api"

  class Error < StandardError; end

  def initialize(token)
    @token = token
  end

  # Returns the ts of the posted message
  def post_message(channel:, text:, thread_ts: nil)
    request("chat.postMessage", { channel: channel, text: text, thread_ts: thread_ts }.compact).fetch("ts")
  end

  private

  def request(method, payload)
    uri = URI("#{BASE_URL}/#{method}")
    response = Net::HTTP.post(uri, payload.to_json, "Content-Type" => "application/json; charset=utf-8",
                                                    "Authorization" => "Bearer #{@token}")
    body = JSON.parse(response.body)
    raise Error, "Slack #{method} failed: #{body["error"]}" unless body["ok"]

    body
  end
end
