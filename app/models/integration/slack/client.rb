# The few Slack Web API calls OxyBot needs, over plain HTTPS.
class Integration::Slack::Client
  BASE_URL = "https://slack.com/api"

  class Error < StandardError; end

  def initialize(token)
    @token = token
  end

  # Returns the ts of the posted message
  def post_message(channel:, text:, thread_ts: nil)
    # No link previews: a link planted in customer text must not be fetched by Slack without a click
    request("chat.postMessage", { channel: channel, text: text, thread_ts: thread_ts, unfurl_links: false, unfurl_media: false }.compact).fetch("ts")
  end

  def auth_test
    request("auth.test", {})
  end

  private

  def request(method, payload)
    uri = URI("#{BASE_URL}/#{method}")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json; charset=utf-8", "Authorization" => "Bearer #{@token}")
    request.body = payload.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
    body = JSON.parse(response.body)
    raise Error, "Slack #{method} failed: #{body["error"]}" unless body["ok"]

    body
  end
end
