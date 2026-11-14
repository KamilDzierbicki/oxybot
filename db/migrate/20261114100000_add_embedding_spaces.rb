# Records which model made each vector. An alias (oxybot-embed) can be pointed at another model with the same
# dimensions; vectors from two models must never be compared, so every vector names the space it lives in.
class AddEmbeddingSpaces < ActiveRecord::Migration[8.1]
  def change
    create_table :embedding_spaces do |t|
      t.string :model_alias, null: false
      t.string :upstream_model # what LiteLLM serves behind the alias, for people (e.g. "ollama/nomic-embed-text")
      t.vector :probe, limit: 768, null: false # the vector of a fixed sentence: the model's fingerprint
      t.datetime :activated_at, null: false # when the alias last started serving this model
      t.timestamps
    end

    # Existing vectors have no space: they count as stale and are embedded again by ReembedJob
    add_reference :features, :embedding_space, foreign_key: true
    add_reference :insights, :embedding_space, foreign_key: true
  end
end
