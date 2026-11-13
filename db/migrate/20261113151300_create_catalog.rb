class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    create_table :products do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.timestamps
    end
    add_index :products, [ :account_id, :slug ], unique: true

    create_table :features do |t|
      t.references :account, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false, default: ""
      t.string :status, null: false, default: "idea"
      t.vector :embedding, limit: 1536
      t.virtual :search_vector, type: :tsvector, stored: true,
        as: "to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, ''))"
      t.timestamps
    end
    add_index :features, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :features, :search_vector, using: :gin

    create_table :knowledge_documents do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.timestamps
    end
  end
end
