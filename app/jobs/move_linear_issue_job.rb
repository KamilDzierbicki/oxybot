class MoveLinearIssueJob < ApplicationJob
  queue_as :default
  retry_on Integration::Linear::Client::Error, Net::OpenTimeout, wait: :polynomially_longer, attempts: 5

  def perform(feature) = feature.move_linear_issue
end
