require "test_helper"

class AiBudgetTest < ActiveSupport::TestCase
  LITELLM = "http://litellm.test"

  setup do
    @account = accounts(:acme)
    Rails.configuration.x.mock_llm = false
    Rails.configuration.x.llm_url = "#{LITELLM}/v1"
    stub_request(:get, "#{LITELLM}/v1/models").to_return(body: { data: [] }.to_json)
  end

  teardown do
    Rails.configuration.x.mock_llm = true
    Rails.configuration.x.llm_url = "http://mock-llm.test/v1"
  end

  test "a new budget is a named LiteLLM budget with a one-day window, attached to the workspace's customer" do
    stub_request(:get, "#{LITELLM}/customer/info?end_user_id=account-#{@account.id}").to_return(status: 404, body: "{}")
    stub_request(:post, "#{LITELLM}/budget/update").to_return(status: 404, body: "{}")
    budget = stub_request(:post, "#{LITELLM}/budget/new")
               .with(body: { budget_id: "oxybot-account-#{@account.id}", max_budget: 5.0, budget_duration: "1d" }.to_json).to_return(body: "{}")
    customer = stub_request(:post, "#{LITELLM}/customer/new")
                 .with(body: hash_including(user_id: "account-#{@account.id}", budget_id: "oxybot-account-#{@account.id}")).to_return(body: "{}")
    @account.update_ai_settings("daily_budget_usd" => "5")

    perform_enqueued_jobs(only: SyncAiBudgetJob)

    assert_requested budget # LiteLLM 1.90 ignores a window given inline with the customer, so it lives on the budget
    assert_requested customer # the id matches the user every model call sends, so LiteLLM counts spend per workspace
  end

  test "changing the budget updates it and keeps it attached to the existing customer" do
    stub_request(:get, "#{LITELLM}/customer/info?end_user_id=account-#{@account.id}").to_return(body: { spend: 1.25 }.to_json)
    updated = stub_request(:post, "#{LITELLM}/budget/update").with(body: hash_including(max_budget: 8.0, budget_duration: "1d")).to_return(body: "{}")
    attached = stub_request(:post, "#{LITELLM}/customer/update").with(body: hash_including(budget_id: "oxybot-account-#{@account.id}")).to_return(body: "{}")

    @account.update_ai_settings("daily_budget_usd" => "8")
    @account.sync_ai_budget

    assert_requested updated
    assert_requested attached
    assert_equal 1.25, @account.ai_spend_today
  end

  test "0 removes the cap by deleting the customer, since LiteLLM ignores a null budget on update" do
    stub_request(:get, "#{LITELLM}/customer/info?end_user_id=account-#{@account.id}").to_return(body: { spend: 1.25 }.to_json)
    deleted = stub_request(:post, "#{LITELLM}/customer/delete").with(body: { user_ids: [ "account-#{@account.id}" ] }.to_json).to_return(body: "{}")

    @account.update_ai_settings("daily_budget_usd" => "0")
    @account.sync_ai_budget

    assert_requested deleted
  end

  test "saving other settings does not touch LiteLLM" do
    assert_no_enqueued_jobs(only: SyncAiBudgetJob) { @account.update_ai_settings("match_candidates" => "7") }
  end

  test "an assistant answer over budget says so instead of asking to retry" do
    Rails.configuration.x.mock_llm = true
    Rails.configuration.x.llm_url = "http://mock-llm.test/v1"
    stub_request(:post, %r{mock-llm\.test/v1/chat/completions}).to_return(status: 429, body: {
      error: { message: "ExceededBudget: End User=account-#{@account.id} over budget.", type: "budget_exceeded", code: "429" }
    }.to_json)
    conversation = users(:kamil).conversations.create!(account: @account)

    reply = conversation.ask("Anything new?")
    perform_enqueued_jobs(only: GenerateReplyJob)

    assert_equal LiteLlm::BUDGET_MESSAGE, reply.reload.content
  end
end
