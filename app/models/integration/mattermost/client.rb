# Mattermost REST API v4 with a bot account's access token.
class Integration::Mattermost::Client
  class Error < StandardError; end

  def initialize(server_url, token)
    @server_url = server_url.to_s.chomp("/")
    @token = token
  end

  def me
    request(Net::HTTP::Get, "#{@server_url}/api/v4/users/me")
  end

  # Returns the new post's id
  def create_post(channel_id:, message:, root_id: nil)
    request(Net::HTTP::Post, "#{@server_url}/api/v4/posts", { channel_id: channel_id, message: message, root_id: root_id }.compact).fetch("id")
  end

  # Answers a slash command through its response_url; only the asker sees an ephemeral response
  def respond(response_url, text)
    request(Net::HTTP::Post, response_url, { response_type: "ephemeral", text: text }, authorize: false)
    "response-#{SecureRandom.hex(6)}"
  end

  private

  def request(method, url, payload = nil, authorize: true)
    Integration::OutboundUrl.check!(url)
    uri = URI(url)
    request = method.new(uri, "Content-Type" => "application/json")
    request["Authorization"] = "Bearer #{@token}" if authorize
    request.body = payload.to_json if payload
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
    raise Error, "Mattermost #{uri.path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body.present? ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end
end
