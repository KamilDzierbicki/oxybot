require "test_helper"

# What the app sends to LiteLLM must work for every provider behind it, not only OpenAI
class LlmRequestTest < ActiveSupport::TestCase
  test "the tenant goes in the standard user field, never OpenAI-only parameters Anthropic rejects" do
    accounts(:acme).feedback_notes.create!(source: "manual", body: "Please add PDF export of reports for finance.").extract_insights

    body = JSON.parse(llm_requests("oxybot-extract").first.body)
    assert_equal "account-#{accounts(:acme).id}", body["user"]
    assert_not body.key?("safety_identifier"), "LiteLLM refuses safety_identifier for Anthropic models"
    assert_equal "extract-insights", body.dig("metadata", "generation_name")
  end

  test "instructions are sent with the system role" do
    accounts(:acme).feedback_notes.create!(source: "manual", body: "Please add PDF export of reports for finance.").extract_insights

    roles = JSON.parse(llm_requests("oxybot-extract").first.body)["messages"].map { |message| message["role"] }
    assert_equal "system", roles.first
  end
end
