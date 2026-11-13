class AddDocumentsSkillsAndDelivery < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :custom_instructions, :text
    add_column :users, :custom_instructions, :text
    # SHA-256 of the personal MCP token; the token itself is shown once
    add_column :users, :mcp_token_digest, :string
    add_index :users, :mcp_token_digest, unique: true

    add_column :features, :released_at, :datetime
    add_column :features, :linear_issue_id, :string
    add_column :features, :linear_identifier, :string
    add_column :features, :linear_url, :string
    add_column :features, :linear_state, :string
    add_index :features, [ :account_id, :linear_issue_id ], unique: true, where: "linear_issue_id IS NOT NULL"

    add_column :integrations, :webhook_secret, :text

    create_table :document_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :document_templates, [ :account_id, :kind ]

    create_table :documents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :feature, foreign_key: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :document_template, foreign_key: true
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.string :status, null: false, default: "drafting"
      t.boolean :auto_accept, null: false, default: false
      t.bigint :cited_insight_ids, array: true, null: false, default: []
      t.timestamps
    end
    add_index :documents, [ :account_id, :kind ]

    create_table :document_versions do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, foreign_key: true # nil: written by the agent
      t.text :body, null: false
      t.string :summary
      t.timestamps
    end

    create_table :document_suggestions do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :base_version, foreign_key: { to_table: :document_versions }
      t.text :instruction, null: false
      t.text :body
      t.text :rationale
      t.string :status, null: false, default: "thinking"
      t.timestamps
    end

    create_table :skills do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: true # nil: shared with the whole team
      t.string :name, null: false
      t.string :description, null: false
      t.text :instructions, null: false
      t.timestamps
    end
    add_index :skills, [ :account_id, :user_id, :name ], unique: true, nulls_not_distinct: true
  end
end
