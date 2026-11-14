# Hybrid search inside the current scope: vector and full-text candidates fused with reciprocal rank fusion.
# Call it on a scoped relation (account.insights, product.features), so the tenant boundary is the scope itself.
module HybridSearchable
  extend ActiveSupport::Concern

  # The defaults; an agent's prompt config can tune each (Prompt.retrieval). rrf_k 60 is the usual constant from the
  # RRF paper: one list's first place cannot decide alone
  TUNING = { "candidates" => 20, "rrf_k" => 60, "vector_weight" => 1.0, "text_weight" => 1.0 }.freeze

  class_methods do
    # The query vector must come from the same model as the stored ones: pass both vector and its space, or neither
    def hybrid_search(text, vector: nil, space: nil, limit: 8, tuning: {})
      if vector.nil?
        space, vectors = EmbeddingSpace.embed([ text ], task: :query)
        vector = vectors.first
      end
      ranked(text, mode: :hybrid, vector: vector, space: space, tuning: tuning).first(limit)
    end

    # Full-text only: no model call, for the search box
    def keyword_search(text, limit: 8)
      text_matches(text).first(limit)
    end

    # The ranking of one search mode (:vector, :text or :hybrid), for measuring retrieval (Evaluation)
    def ranked(text, mode:, vector:, space:, tuning: {})
      tuning = TUNING.merge(tuning.to_h.stringify_keys.slice(*TUNING.keys))
      case mode
      when :vector then vector_matches(vector, space, tuning["candidates"])
      when :text then text_matches(text, tuning["candidates"])
      when :hybrid
        fuse({ vector_matches(vector, space, tuning["candidates"]) => tuning["vector_weight"],
               text_matches(text, tuning["candidates"]) => tuning["text_weight"] }, tuning["rrf_k"])
      else raise ArgumentError, "unknown search mode #{mode}"
      end
    end

    private

    # Only vectors from the query's model: distances between two models' vectors mean nothing
    def vector_matches(vector, space, candidates)
      return [] if space.nil?

      transaction do
        # With a WHERE on account or product, HNSW alone can return fewer rows than asked (pgvector 0.8+)
        connection.execute("SET LOCAL hnsw.iterative_scan = relaxed_order")
        all.where(embedding_space: space).where.not(embedding: nil).nearest_neighbors(:embedding, vector, distance: "cosine").first(candidates)
      end
    end

    # Any word may match, and as a prefix ("eksport:*"), which also catches Polish inflections. Ties keep id order, so
    # two runs of an experiment rank alike
    def text_matches(text, candidates = TUNING["candidates"])
      words = text.to_s.downcase.scan(/[[:alnum:]]{3,}/).uniq.first(12)
      return [] if words.empty?

      tsquery = sanitize_sql_array([ "to_tsquery('simple', ?)", words.map { |word| "#{word}:*" }.join(" | ") ])
      all.where("#{table_name}.search_vector @@ #{tsquery}")
         .order(Arel.sql("ts_rank_cd(#{table_name}.search_vector, #{tsquery}) DESC"), :id).limit(candidates).to_a
    end

    # Weighted reciprocal rank fusion: { list => weight }
    def fuse(weighted_lists, rrf_k)
      scores = Hash.new(0.0)
      records = {}
      weighted_lists.each do |list, weight|
        list.each.with_index(1) do |record, rank|
          scores[record.id] += weight / (rrf_k + rank)
          records[record.id] ||= record
        end
      end
      scores.sort_by { |id, score| [ -score, id ] }.map { |id, _score| records.fetch(id) }
    end
  end
end
