# Issues a new MCP token for coding agents; any previous token stops working
class Profiles::McpTokensController < ApplicationController
  def create
    flash[:mcp_token] = Current.user.generate_mcp_token
    redirect_to profile_path
  end
end
