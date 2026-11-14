# Ranking quality for one query: reciprocal rank (1 / position of the first relevant result, 0 if none in the
# ranking) and recall@k (share of the relevant results found in the first k).
module Evaluation::RetrievalMetrics
  module_function

  def reciprocal_rank(ranking, relevant)
    position = ranking.index { |key| relevant.include?(key) }
    position ? 1.0 / (position + 1) : 0.0
  end

  def recall_at(k, ranking, relevant)
    return 0.0 if relevant.empty?

    (ranking.first(k) & relevant).size.fdiv(relevant.size)
  end
end
