class OpportunityDiscoveryJob < ApplicationJob
  queue_as :default

  # Without an account: the weekly run (config/recurring.yml) covers every account
  def perform(account = nil)
    account ? account.discover_opportunities : Account.find_each { |each_account| OpportunityDiscoveryJob.perform_later(each_account) }
  end
end
