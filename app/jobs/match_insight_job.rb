class MatchInsightJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 4, key: ->(insight) { insight.account_id }, duration: 5.minutes
  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError, RubyLLM::ServerError, wait: :polynomially_longer, attempts: 5

  def perform(insight) = insight.match
end
