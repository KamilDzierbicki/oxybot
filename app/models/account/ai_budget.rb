# A daily spending cap per workspace, enforced by LiteLLM. Every model call already names its workspace as the
# end user ("account-<id>"), so LiteLLM counts spend per workspace; this keeps a LiteLLM customer with that id and
# the cap from AI settings, and reads back what was spent in the current day.
module Account::AiBudget
  extend ActiveSupport::Concern

  def llm_customer_id = "account-#{id}"

  # Called after the budget setting changes. 0 means no workspace cap (the per-alias caps in litellm.yaml still apply).
  # The cap is a named LiteLLM budget with a one-day window (LiteLLM 1.90 ignores a window given inline with the
  # customer), attached to the customer. LiteLLM ignores a null budget on update, so removing the cap deletes the
  # customer. LiteLLM caches customers for about a minute, so a change takes effect within that time.
  def sync_ai_budget
    return unless LiteLlm.available?

    budget = ai_setting("daily_budget_usd").to_f
    customer = llm_customer
    return (LiteLlm.post("/customer/delete", { user_ids: [ llm_customer_id ] }) if customer) unless budget.positive?

    save_llm_budget(budget)
    if customer
      LiteLlm.post("/customer/update", { user_id: llm_customer_id, budget_id: llm_budget_id })
    else
      LiteLlm.post("/customer/new", { user_id: llm_customer_id, alias: name, budget_id: llm_budget_id })
    end
  end

  def llm_budget_id = "oxybot-#{llm_customer_id}"

  # Spend in the current budget window, or nil when LiteLLM cannot tell
  def ai_spend_today
    llm_customer&.fetch("spend", nil)&.to_f
  rescue LiteLlm::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED
    nil
  end

  private

  def save_llm_budget(amount)
    budget = { budget_id: llm_budget_id, max_budget: amount, budget_duration: "1d" }
    LiteLlm.post("/budget/update", budget)
  rescue LiteLlm::Error => e
    raise unless e.message.match?(/answered (400|404)/)

    LiteLlm.post("/budget/new", budget)
  end

  def llm_customer
    return unless LiteLlm.available?

    LiteLlm.get("/customer/info?end_user_id=#{ERB::Util.url_encode(llm_customer_id)}")
  rescue LiteLlm::Error => e
    raise unless e.message.match?(/answered (400|404)/)
  end
end
