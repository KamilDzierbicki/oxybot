class OpportunityDiscoveryJob < ApplicationJob
  queue_as :default

  # Runs every hour (config/recurring.yml) and drafts the report for each account whose chosen day and hour it is.
  # With an account it drafts that account's report right away.
  def perform(account = nil)
    return account.discover_opportunities if account

    Account.find_each { |each_account| each_account.discover_opportunities if each_account.opportunity_report_due? }
  end
end
