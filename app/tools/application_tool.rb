# Base class for the assistant's tools. Each tool is built per turn and reads only that turn's account.
# A recoverable failure (database timeout, embeddings proxy down) becomes an error result the model can
# read and work around; programming errors still raise, so bugs fail loud.
class ApplicationTool < RubyLLM::Tool
  rescue_from ActiveRecord::ActiveRecordError, RubyLLM::Error, Faraday::Error, Timeout::Error do |error|
    Rails.logger.warn("[tools] #{name} failed: #{error.class}: #{error.message}")
    { error: "The #{name} tool failed (#{error.class.name.demodulize}). Answer without it and say the data was unavailable." }
  end

  def initialize(turn)
    @turn = turn
  end

  # The assistant's tools are described in the product-agent prompt's config, versioned with the prompt; the others
  # (code search for documents) keep their description in the class
  def description
    Prompt.config("product-agent").dig("tools", name).presence || super
  end

  private

  attr_reader :turn

  delegate :account, to: :turn

  def product_scope(scope, slug)
    slug.present? ? scope.joins(:product).where(products: { slug: slug }) : scope
  end

  def arr(cents)
    turn.revenue_visible? ? ActiveSupport::NumberHelper.number_to_currency(cents / 100, precision: 0) : nil
  end
end
