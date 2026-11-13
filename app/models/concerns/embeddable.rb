# A record with a pgvector embedding of #embedding_text, made by the oxybot-embed alias in LiteLLM
# (Ollama's nomic-embed-text by default, 768 dimensions).
module Embeddable
  extend ActiveSupport::Concern

  MODEL = "oxybot-embed"
  DIMENSIONS = 768
  # nomic-embed-text expects a task prefix, different for stored texts and for search queries
  PREFIXES = { document: "search_document: ", query: "search_query: " }.freeze

  included do
    has_neighbors :embedding
  end

  class_methods do
    def embed(text, task: :document)
      RubyLLM.embed(PREFIXES.fetch(task) + text.to_s, model: MODEL, provider: :openai, assume_model_exists: true).vectors
    end
  end

  def embed
    update_column(:embedding, self.class.embed(embedding_text))
  end
end
