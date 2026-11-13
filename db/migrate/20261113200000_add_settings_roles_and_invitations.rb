class AddSettingsRolesAndInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :ai_settings, :jsonb, null: false, default: {}
    add_column :accounts, :time_zone, :string, null: false, default: "UTC"
    add_column :users, :role, :string, null: false, default: "member"

    create_table :invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token_digest, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :account_id, :email ]
  end
end
