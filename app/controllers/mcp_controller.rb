# MCP endpoint for coding agents: `claude mcp add --transport http oxybot <url>/mcp --header "Authorization: Bearer <token>"`.
# Each request builds a server for the token's user, so tools only see that user's account.
class McpController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  include ActionController::RateLimiting

  before_action :refuse_foreign_origin
  # Guessing tokens is limited per address (checked before authentication); use per user after it
  rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip }, with: -> { head :too_many_requests }, name: "address"
  before_action :authenticate
  rate_limit to: 120, within: 1.minute, by: -> { @user.id }, with: -> { head :too_many_requests }, name: "user"

  def handle
    server = MCP::Server.new(
      name: "oxybot", title: "OxyBot", version: "1.0.0",
      instructions: "Product specs and customer evidence from OxyBot. Read a spec with get_spec before implementing its feature.",
      tools: [ SpecServer::ListSpecsTool, SpecServer::GetSpecTool, SpecServer::SearchFeedbackTool ],
      server_context: { user: @user }
    )
    # DNS rebinding protection guards servers that trust the browser's localhost; here Rails checks the Host
    # header (config.hosts) and every request needs a bearer token, which a rebound page cannot read.
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true, enable_json_response: true,
                                                                              serve_subscriptions_listen: false, dns_rebinding_protection: false)
    status, headers, body = transport.handle_request(request)
    render json: body.first, status: status, headers: headers
  end

  private

  # Browsers send Origin; coding agents do not. A page on another site must not reach the tools.
  def refuse_foreign_origin
    origin = request.headers["Origin"]
    return if origin.blank? || URI.parse(origin).host == request.host

    head :forbidden
  rescue URI::InvalidURIError
    head :forbidden
  end

  def authenticate
    @user = authenticate_with_http_token { |token, _options| User.find_by_mcp_token(token) }
    head :unauthorized, "WWW-Authenticate" => %(Bearer realm="OxyBot") unless @user
  end
end
