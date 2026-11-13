# Finds the feature an insight asks for: hybrid search narrows the product's backlog to a few candidates,
# then the flint-judge model picks one or none. The result is only a suggestion; a PM confirms it.
module Insight::Matchable
  extend ActiveSupport::Concern

  CANDIDATES = 5

  included do
    after_create_commit :match_later
  end

  def match_later
    MatchInsightJob.perform_later(self)
  end

  def match
    embed if embedding.nil?
    candidates = product.features.hybrid_search(summary, vector: embedding, limit: CANDIDATES)
    return update!(suggested_feature: nil, match_confidence: nil, match_reason: "No features in #{product.name} yet.") if candidates.empty?

    verdict = FeatureJudge.new(insight: self, candidates: candidates).ask("Which feature does this insight ask for?").parsed || {}
    # The model can only pick from the candidates it was shown
    suggested = candidates.find { |feature| feature.id == verdict["feature_id"] }
    update!(suggested_feature: suggested, match_confidence: verdict["confidence"].to_f.clamp(0, 1),
            match_reason: verdict["reason"].to_s.truncate(250))
  end
end
