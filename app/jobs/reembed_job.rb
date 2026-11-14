# Brings one workspace's vectors to the model the alias serves now, in batches of one embedding call each.
# Progress is the data itself (stale rows), so a rerun continues where the last one stopped; a deploy interrupts
# it at a batch boundary and it resumes on its own. An hourly sweep restarts runs that died without notice.
class ReembedJob < ApplicationJob
  include ActiveJob::Continuable

  BATCH = 64

  queue_as :default
  limits_concurrency to: 1, key: ->(account) { account.id }, duration: 1.hour
  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError, RubyLLM::ServerError, Faraday::Error,
           wait: :polynomially_longer, attempts: 8

  def self.sweep
    Account.find_each { |account| perform_later(account) if account.stale_embeddings? }
  end

  def perform(account)
    step(:features) { |step| reembed(account.features, step) }
    step(:insights) { |step| reembed(account.insights, step) }
    step(:knowledge_chunks) { |step| reembed(account.knowledge_chunks.includes(:knowledge_document), step) }
  end

  private

  def reembed(scope, step)
    loop do
      batch = scope.stale_embeddings.order(:id).limit(BATCH).to_a
      break if batch.empty?

      scope.klass.embed_all(batch)
      # The model changed during the run; the job enqueued for the new model takes over
      break if batch.first.reload.embedding_space_id != EmbeddingSpace.active&.id

      step.checkpoint!
    end
  end
end
