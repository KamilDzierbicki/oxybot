require "test_helper"

class McpTest < ActionDispatch::IntegrationTest
  setup do
    @token = users(:kamil).generate_mcp_token
    @spec = Document.create!(account: accounts(:acme), feature: features(:pdf_export), kind: "prd", title: "Spec: PDF export",
                             status: "ready", body: "## Summary\nExport reports to PDF.")
  end

  test "refuses requests without a valid token" do
    rpc("tools/list", token: "osp_wrong")

    assert_response :unauthorized
  end

  test "lists the spec tools as read-only" do
    rpc("tools/list")

    tools = response.parsed_body.dig("result", "tools")
    assert_equal %w[get_spec list_specs search_feedback], tools.map { |tool| tool["name"] }.sort
    assert tools.all? { |tool| tool.dig("annotations", "readOnlyHint") }
  end

  test "returns the account's spec to a coding agent" do
    rpc("tools/call", params: { name: "get_spec", arguments: { id: @spec.id } })

    assert_includes response.parsed_body.dig("result", "content", 0, "text"), "Export reports to PDF."
  end

  test "another account's token cannot read the spec" do
    rpc("tools/call", params: { name: "get_spec", arguments: { id: @spec.id } }, token: users(:eve).generate_mcp_token)

    assert_includes response.parsed_body.dig("result", "content", 0, "text"), "No spec with id"
  end

  test "a new token replaces the old one" do
    users(:kamil).generate_mcp_token

    rpc("tools/list")

    assert_response :unauthorized
  end

  private

  def rpc(method, params: {}, token: @token)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
                 headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json",
                            "Accept" => "application/json, text/event-stream", "MCP-Protocol-Version" => "2025-06-18" }
  end
end
