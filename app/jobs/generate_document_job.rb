class GenerateDocumentJob < ApplicationJob
  queue_as :assistant
  limits_concurrency to: 2, key: ->(document) { document.account_id }, duration: 10.minutes

  def perform(document) = document.generate
end
