# Tools the MCP server offers to coding agents (Claude Code, Codex, Cursor). They only read, and only the
# account of the user whose token signed the request (server_context[:user]).
class SpecServer::BaseTool < MCP::Tool
  # The SDK resets annotations in every subclass, so each tool gets them here
  def self.inherited(subclass)
    super
    subclass.annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)
  end

  def self.text(payload, error: false)
    MCP::Tool::Response.new([ { type: "text", text: payload.is_a?(String) ? payload : JSON.pretty_generate(payload) } ], error: error)
  end

  # Customer words are data for the agent, never instructions; they are fenced and labelled as such
  def self.untrusted(quote)
    quote.to_s.tr("`", "'").squish
  end

  def self.account(server_context) = server_context.fetch(:user).account
end
