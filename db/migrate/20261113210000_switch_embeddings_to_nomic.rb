# Embeddings move to a local model (Ollama nomic-embed-text, 768 dimensions), so no OpenAI key is needed and
# feedback never leaves the server for embedding. Existing vectors are dropped; `bin/rails oxybot:reembed` rebuilds them.
class SwitchEmbeddingsToNomic < ActiveRecord::Migration[8.1]
  def change
    %i[insights features].each do |table|
      remove_index table, :embedding, using: :hnsw, opclass: :vector_cosine_ops
      remove_column table, :embedding, :vector, limit: 1536
      add_column table, :embedding, :vector, limit: 768
      add_index table, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    end
  end
end
