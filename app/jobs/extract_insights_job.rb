class ExtractInsightsJob < ApplicationJob
  queue_as :default
  # One tenant importing thousands of notes must not hold every worker
  limits_concurrency to: 2, key: ->(note) { note.account_id }, duration: 5.minutes
  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError, RubyLLM::ServerError, JSON::ParserError, wait: :polynomially_longer, attempts: 5

  def perform(note) = note.extract_insights
end
