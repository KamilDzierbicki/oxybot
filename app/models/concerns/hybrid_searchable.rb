# Hybrid search inside the current scope: vector and full-text candidates fused with reciprocal rank fusion.
# Call it on a scoped relation (account.insights, product.features), so the tenant boundary is the scope itself.
module HybridSearchable
  extend ActiveSupport::Concern

  CANDIDATES = 20
  RRF_K = 60 # the usual constant from the RRF paper; one list's first place cannot decide alone

  class_methods do
    # The query vector must come from the same model as the stored ones: pass both vector and its space, or neither
    def hybrid_search(text, vector: nil, space: nil, limit: 8)
      if vector.nil?
        space, vectors = EmbeddingSpace.embed([ text ], task: :query)
        vector = vectors.first
      end
      fuse(vector_matches(vector, space), text_matches(text)).first(limit)
    end

    # Full-text only: no model call, for the search box
    def keyword_search(text, limit: 8)
      text_matches(text).first(limit)
    end

    # The ranking of one search mode (:vector, :text or :hybrid), for measuring retrieval (Evaluation)
    def ranked(text, mode:, vector:, space:)
      case mode
      when :vector then vector_matches(vector, space)
      when :text then text_matches(text)
      when :hybrid then fuse(vector_matches(vector, space), text_matches(text))
      else raise ArgumentError, "unknown search mode #{mode}"
      end
    end

    private

    # Only vectors from the query's model: distances between two models' vectors mean nothing
    def vector_matches(vector, space)
      return [] if space.nil?

      transaction do
        # With a WHERE on account or product, HNSW alone can return fewer rows than asked (pgvector 0.8+)
        connection.execute("SET LOCAL hnsw.iterative_scan = relaxed_order")
        all.where(embedding_space: space).where.not(embedding: nil).nearest_neighbors(:embedding, vector, distance: "cosine").first(CANDIDATES)
      end
    end

    # Any word may match, and as a prefix ("eksport:*"), which also catches Polish inflections
    def text_matches(text)
      words = text.to_s.downcase.scan(/[[:alnum:]]{3,}/).uniq.first(12)
      return [] if words.empty?

      tsquery = sanitize_sql_array([ "to_tsquery('simple', ?)", words.map { |word| "#{word}:*" }.join(" | ") ])
      all.where("#{table_name}.search_vector @@ #{tsquery}")
         .order(Arel.sql("ts_rank_cd(#{table_name}.search_vector, #{tsquery}) DESC")).limit(CANDIDATES).to_a
    end

    def fuse(*lists)
      scores = Hash.new(0.0)
      records = {}
      lists.each do |list|
        list.each.with_index(1) do |record, rank|
          scores[record.id] += 1.0 / (RRF_K + rank)
          records[record.id] ||= record
        end
      end
      scores.sort_by { |id, score| [ -score, id ] }.map { |id, _score| records.fetch(id) }
    end
  end
end
