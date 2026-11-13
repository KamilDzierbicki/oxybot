class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :domain
      t.string :hubspot_id
      t.bigint :arr_cents, null: false, default: 0
      t.string :plan
      t.datetime :synced_at
      t.timestamps
    end
    add_index :customers, [:account_id, :domain], unique: true, where: "domain IS NOT NULL"
    add_index :customers, [:account_id, :hubspot_id], unique: true, where: "hubspot_id IS NOT NULL"

    create_table :contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :email, null: false
      t.string :name
      t.string :hubspot_id
      t.timestamps
    end
    add_index :contacts, [:account_id, :email], unique: true
  end
end
