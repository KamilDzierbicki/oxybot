# Long knowledge documents are split into sections the agent searches, instead of going into every prompt in full
class CreateKnowledgeChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_chunks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :knowledge_document, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :heading # the nearest markdown heading above the text, if any
      t.text :body, null: false
      t.vector :embedding, limit: 768
      t.references :embedding_space, foreign_key: true
      t.virtual :search_vector, type: :tsvector, stored: true,
        as: "to_tsvector('simple', coalesce(heading, '') || ' ' || coalesce(body, ''))"
      t.timestamps
    end
    add_index :knowledge_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :knowledge_chunks, :search_vector, using: :gin
    add_index :knowledge_chunks, [ :knowledge_document_id, :position ], unique: true
  end
end
