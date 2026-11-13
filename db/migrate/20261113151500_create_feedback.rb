class CreateFeedback < ActiveRecord::Migration[8.1]
  def change
    create_table :feedback_notes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :source, null: false
      # Id in the source system (Slack "channel:ts"); the unique index makes a redelivered webhook a no-op
      t.string :external_id
      t.string :author
      t.string :author_email
      t.text :body, null: false
      t.datetime :processed_at
      t.timestamps
    end
    add_index :feedback_notes, [ :account_id, :source, :external_id ], unique: true, where: "external_id IS NOT NULL"

    create_table :insights do |t|
      t.references :account, null: false, foreign_key: true
      t.references :feedback_note, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      # The model's proposal and the PM's decision are kept apart, so their agreement can be measured
      t.references :suggested_feature, foreign_key: { to_table: :features }
      t.references :feature, foreign_key: true
      t.text :quote, null: false
      t.string :summary, null: false
      t.string :urgency, null: false, default: "medium"
      t.string :triage_state, null: false, default: "pending"
      t.float :match_confidence
      t.string :match_reason
      t.vector :embedding, limit: 1536
      t.virtual :search_vector, type: :tsvector, stored: true,
        as: "to_tsvector('simple', coalesce(summary, '') || ' ' || coalesce(quote, ''))"
      t.timestamps
    end
    add_index :insights, [ :account_id, :triage_state ]
    add_index :insights, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :insights, :search_vector, using: :gin
  end
end
