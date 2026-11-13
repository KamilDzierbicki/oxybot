class EmbedJob < ApplicationJob
  queue_as :default
  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError, RubyLLM::ServerError, wait: :polynomially_longer, attempts: 5

  def perform(record) = record.embed
end
