class SyncAiBudgetJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(account) { account.id }
  retry_on LiteLlm::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 5

  def perform(account) = account.sync_ai_budget
end
