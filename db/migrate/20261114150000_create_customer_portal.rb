# The customer portal: a public roadmap per workspace, where customers sign in with a link sent to their email,
# vote for features and submit ideas
class CreateCustomerPortal < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :portal_slug, :string
    add_column :accounts, :portal_enabled, :boolean, default: false, null: false
    add_index :accounts, :portal_slug, unique: true

    create_table :portal_visitors do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :email, null: false
      t.datetime :last_signed_in_at
      t.timestamps
    end
    add_index :portal_visitors, [ :account_id, :email ], unique: true
    add_check_constraint :portal_visitors, "email = lower(email)", name: "portal_visitors_email_lowercase"

    create_table :portal_votes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :portal_visitor, null: false, foreign_key: true
      t.references :feature, null: false, foreign_key: true
      t.references :feedback_note, null: false, foreign_key: true
      t.timestamps
    end
    add_index :portal_votes, [ :portal_visitor_id, :feature_id ], unique: true
  end
end
