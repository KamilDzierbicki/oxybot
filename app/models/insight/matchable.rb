# Finds the feature an insight asks for: hybrid search narrows the product's backlog to a few candidates,
# then the oxybot-judge model picks one or none. The result is only a suggestion; a PM confirms it.
module Insight::Matchable
  extend ActiveSupport::Concern

  included do
    after_create_commit :match_later
  end

  def match_later
    MatchInsightJob.perform_later(self)
  end

  def match
    return unless Rails.configuration.x.ai_enabled

    embed unless embedding_current?
    candidates = product.features.hybrid_search(summary, vector: embedding, space: embedding_space, limit: account.ai_setting("match_candidates"))
    return update!(suggested_feature: nil, match_confidence: nil, match_reason: "No features in #{product.name} yet.") if candidates.empty?

    question = "<insight>\nInsight: #{summary.squish}\nQuote: #{quote.squish}\n</insight>\n\nWhich feature does this insight ask for?"
    verdict = FeatureJudge.new(insight: self, candidates: candidates).ask(question).parsed || {}
    # The model can only pick from the candidates it was shown
    suggested = candidates.find { |feature| feature.id == verdict["feature_id"] }
    update!(suggested_feature: suggested, match_confidence: verdict["confidence"].to_f.clamp(0, 1),
            match_reason: readable_reason(verdict["reason"], candidates))
  end

  private

  # Models sometimes refer to features as "candidate 26" or "[26]"; people know them by title
  def readable_reason(reason, candidates)
    titles = candidates.to_h { |feature| [ feature.id, feature.title ] }
    reason.to_s.gsub(/\b(?:candidate|feature)\s*#?\[?(\d+)\]?|\[(\d+)\]/i) do
      id = ($1 || $2).to_i
      titles.key?(id) ? "“#{titles[id]}”" : $&
    end.truncate(250)
  end
end
