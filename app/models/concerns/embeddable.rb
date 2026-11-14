# A record with a pgvector embedding of #embedding_text, made by the oxybot-embed alias in LiteLLM
# (Ollama's nomic-embed-text by default, 768 dimensions). Each vector names its EmbeddingSpace (the model that
# made it); vectors are only compared within one space.
module Embeddable
  extend ActiveSupport::Concern

  MODEL = "oxybot-embed"
  DIMENSIONS = 768
  # nomic-embed-text expects a task prefix, different for stored texts and for search queries
  PREFIXES = { document: "search_document: ", query: "search_query: " }.freeze

  included do
    has_neighbors :embedding
    belongs_to :embedding_space, optional: true

    # Never embedded, or embedded by a model the alias no longer serves
    scope :stale_embeddings, -> {
      active = EmbeddingSpace.active
      active ? where(embedding_space_id: nil).or(where.not(embedding_space_id: active.id)) : all
    }
  end

  class_methods do
    # Embeds many records in one call; a batch is written together, so an interrupted run loses at most one batch
    def embed_all(records)
      return if records.empty?

      space, vectors = EmbeddingSpace.embed(records.map(&:embedding_text))
      transaction do
        records.zip(vectors) { |record, vector| record.update_columns(embedding: vector, embedding_space_id: space.id) }
      end
    end
  end

  def embed
    self.class.embed_all([ self ])
  end

  def embedding_current? = embedding.present? && embedding_space_id.present? && embedding_space_id == EmbeddingSpace.active&.id
end
