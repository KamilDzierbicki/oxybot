# Overlap between a generated text and a reference: ROUGE-1, ROUGE-2 and ROUGE-L F1, and BLEU-4 with add-one
# smoothing and the brevity penalty. Words are lowercase letters and digits. All scores are between 0 and 1.
# They reward wording close to one reference, so compare runs against each other (models, prompt versions)
# rather than reading them as an absolute quality grade.
module Evaluation::TextMetrics
  module_function

  def scores(candidate, reference)
    candidate_words = words(candidate)
    reference_words = words(reference)
    { "rouge1" => rouge_n(candidate_words, reference_words, 1), "rouge2" => rouge_n(candidate_words, reference_words, 2),
      "rougeL" => rouge_l(candidate_words, reference_words), "bleu" => bleu(candidate_words, reference_words) }.transform_values { |value| value.round(4) }
  end

  def words(text) = text.to_s.downcase.scan(/[[:alnum:]]+/)

  def rouge_n(candidate, reference, n)
    overlap = clipped_overlap(candidate, reference, n)
    f1(overlap, ngrams(candidate, n).size, ngrams(reference, n).size)
  end

  def rouge_l(candidate, reference)
    f1(lcs_length(candidate, reference), candidate.size, reference.size)
  end

  # Geometric mean of modified n-gram precisions (n = 1..4); orders above 1 get add-one smoothing so a short text
  # without a matching 4-gram does not score exactly 0
  def bleu(candidate, reference, max_n: 4)
    return 0.0 if candidate.empty? || reference.empty?

    log_precisions = (1..max_n).map do |n|
      matches = clipped_overlap(candidate, reference, n)
      total = ngrams(candidate, n).size
      matches, total = matches + 1, total + 1 if n > 1
      return 0.0 if matches.zero? || total.zero?

      Math.log(matches.fdiv(total))
    end
    brevity = candidate.size > reference.size ? 1.0 : Math.exp(1 - reference.size.fdiv(candidate.size))
    brevity * Math.exp(log_precisions.sum / max_n)
  end

  def ngrams(words, n) = words.each_cons(n).to_a

  def clipped_overlap(candidate, reference, n)
    reference_counts = ngrams(reference, n).tally
    ngrams(candidate, n).tally.sum { |gram, count| [ count, reference_counts.fetch(gram, 0) ].min }
  end

  def f1(overlap, candidate_total, reference_total)
    return 0.0 if overlap.zero? || candidate_total.zero? || reference_total.zero?

    precision = overlap.fdiv(candidate_total)
    recall = overlap.fdiv(reference_total)
    2 * precision * recall / (precision + recall)
  end

  def lcs_length(a, b)
    previous = Array.new(b.size + 1, 0)
    a.each do |word|
      current = [ 0 ]
      b.each_with_index { |other, index| current << (word == other ? previous[index] + 1 : [ previous[index + 1], current[index] ].max) }
      previous = current
    end
    previous.last
  end
end
