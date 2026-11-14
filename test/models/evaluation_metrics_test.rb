require "test_helper"

class EvaluationMetricsTest < ActiveSupport::TestCase
  test "reciprocal rank is one over the position of the first relevant result" do
    assert_equal 1.0, Evaluation::RetrievalMetrics.reciprocal_rank(%w[a b c], %w[a])
    assert_equal 1.0 / 3, Evaluation::RetrievalMetrics.reciprocal_rank(%w[x y a], %w[a b])
    assert_equal 0.0, Evaluation::RetrievalMetrics.reciprocal_rank(%w[x y], %w[a])
  end

  test "recall at k counts relevant results within the first k only" do
    assert_equal 0.5, Evaluation::RetrievalMetrics.recall_at(2, %w[a x b], %w[a b])
    assert_equal 1.0, Evaluation::RetrievalMetrics.recall_at(5, %w[a x b], %w[a b])
  end

  test "identical texts score 1 on every text metric, unrelated ones 0" do
    text = "Connect a Shopify store and import its orders and products every hour."

    assert_equal({ "rouge1" => 1.0, "rouge2" => 1.0, "rougeL" => 1.0, "bleu" => 1.0 }, Evaluation::TextMetrics.scores(text, text))
    assert_equal 0.0, Evaluation::TextMetrics.scores("dark mode at night", text)["rouge1"]
  end

  test "ROUGE and BLEU follow their textbook definitions on a small example" do
    candidate = "the cat sat on the mat"
    reference = "the cat is on the mat"

    scores = Evaluation::TextMetrics.scores(candidate, reference)

    assert_in_delta 5.0 / 6, scores["rouge1"], 0.0001, "5 of 6 words overlap (the twice, cat, on, mat)"
    assert_in_delta 3.0 / 5, scores["rouge2"], 0.0001, "the cat, on the, the mat"
    assert_in_delta 5.0 / 6, scores["rougeL"], 0.0001, "longest common subsequence: the cat on the mat"
    assert_operator scores["bleu"], :<, scores["rouge1"], "BLEU also requires matching 3- and 4-grams"
  end
end
