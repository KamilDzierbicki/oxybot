# A record with a pgvector embedding of #embedding_text, made by the flint-embed alias in LiteLLM.
module Embeddable
  extend ActiveSupport::Concern

  MODEL = "flint-embed"

  included do
    has_neighbors :embedding
  end

  class_methods do
    def embed(text)
      RubyLLM.embed(text, model: MODEL, provider: :openai, assume_model_exists: true).vectors
    end
  end

  def embed
    update_column(:embedding, self.class.embed(embedding_text))
  end
end
