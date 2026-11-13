class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :type, null: false
      # Slack team_id or HubSpot portal id: inbound events find their tenant through it
      t.string :external_id, null: false
      t.text :access_token
      t.jsonb :settings, null: false, default: {}
      t.datetime :synced_at
      t.timestamps
    end
    add_index :integrations, [ :type, :external_id ], unique: true
    add_index :integrations, [ :account_id, :type ], unique: true

    create_table :slack_messages do |t|
      t.references :integration, null: false, foreign_key: true
      t.string :direction, null: false
      t.string :channel_id, null: false
      t.string :ts, null: false
      t.string :thread_ts
      t.string :slack_user_id
      t.string :channel_type
      t.boolean :mentions_app, null: false, default: false
      t.text :text, null: false
      t.datetime :processed_at
      t.timestamps
    end
    add_index :slack_messages, [ :integration_id, :channel_id, :ts ], unique: true
  end
end
