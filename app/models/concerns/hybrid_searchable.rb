# Hybrid search inside the current scope: vector and full-text candidates fused with reciprocal rank fusion.
# Call it on a scoped relation (account.insights, product.features), so the tenant boundary is the scope itself.
module HybridSearchable
  extend ActiveSupport::Concern

  CANDIDATES = 20
  RRF_K = 60 # the usual constant from the RRF paper; one list's first place cannot decide alone

  class_methods do
    def hybrid_search(text, vector: nil, limit: 8)
      vector ||= embed(text)
      fuse(vector_matches(vector), text_matches(text)).first(limit)
    end

    private

    def vector_matches(vector)
      transaction do
        # With a WHERE on account or product, HNSW alone can return fewer rows than asked (pgvector 0.8+)
        connection.execute("SET LOCAL hnsw.iterative_scan = relaxed_order")
        all.where.not(embedding: nil).nearest_neighbors(:embedding, vector, distance: "cosine").first(CANDIDATES)
      end
    end

    # Any word may match, and as a prefix ("eksport:*"), which also catches Polish inflections
    def text_matches(text)
      words = text.to_s.downcase.scan(/[[:alnum:]]{3,}/).uniq.first(12)
      return [] if words.empty?

      tsquery = sanitize_sql_array(["to_tsquery('simple', ?)", words.map { |word| "#{word}:*" }.join(" | ")])
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
      scores.sort_by { |id, score| [-score, id] }.map { |id, _score| records.fetch(id) }
    end
  end
end
