class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :slack_user_id
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, [:account_id, :slack_user_id], unique: true, where: "slack_user_id IS NOT NULL"
  end
end
