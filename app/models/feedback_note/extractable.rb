# Splits a note into atomic insights, each assigned to one product, with the oxybot-extract model.
module FeedbackNote::Extractable
  extend ActiveSupport::Concern

  URGENCIES = %w[low medium high].freeze

  included do
    after_create_commit :extract_insights_later
  end

  # Pending insights are replaced; insights a person already linked or dismissed are kept
  def reextract
    transaction do
      insights.pending.destroy_all
      update!(processed_at: nil)
    end
    extract_insights_later
  end

  def extract_insights_later
    ExtractInsightsJob.perform_later(self)
  end

  # Idempotent: a retried job finds processed_at set and does nothing.
  # The note is claimed atomically first, so a retried job and a manual "extract again" never both run it
  def extract_insights
    return unless Rails.configuration.x.ai_enabled
    return unless self.class.where(id: id, processed_at: nil).update_all(processed_at: Time.current) == 1

    reply = InsightExtractor.new(note: self).ask("Feedback:\n#{body}")
    transaction do
      Array(reply.parsed&.dig("insights")).each { |attributes| build_insight(attributes)&.save! }
      touch(:processed_at)
    end
  rescue StandardError
    self.class.where(id: id).update_all(processed_at: nil) # released, so the job retry can run it
    raise
  end

  private

  # The model's output is input: unknown products and empty quotes are dropped, not trusted.
  def build_insight(attributes)
    product = account.products.find_by(slug: attributes["product_slug"])
    quote = attributes["quote"].to_s.strip
    if product.nil? || quote.blank?
      Rails.logger.info("[extract] note #{id}: skipped insight for product #{attributes["product_slug"].inspect}")
      return
    end

    insights.build(
      account: account, product: product, quote: quote,
      summary: attributes["summary"].to_s.strip.presence&.truncate(250) || quote.truncate(250),
      urgency: URGENCIES.include?(attributes["urgency"]) ? attributes["urgency"] : "medium",
      customer: customer || account.customers.named(attributes["customer_name"])
    )
  end
end
