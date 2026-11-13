class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :channel, null: false, default: "web"
      t.string :title
      # A Slack thread is one conversation
      t.string :slack_channel_id
      t.string :slack_thread_ts
      t.timestamps
    end
    add_index :conversations, [ :account_id, :slack_channel_id, :slack_thread_ts ], unique: true,
      where: "slack_thread_ts IS NOT NULL", name: "index_conversations_on_slack_thread"

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.string :status, null: false, default: "done"
      t.jsonb :tool_calls, null: false, default: []
      t.bigint :cited_insight_ids, array: true, null: false, default: []
      t.integer :input_tokens
      t.integer :output_tokens
      t.timestamps
    end
  end
end
