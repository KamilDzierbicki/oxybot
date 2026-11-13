class HardenConstraintsAndIndexes < ActiveRecord::Migration[8.1]
  def change
    # Emails are stored lowercase by the model; the database enforces it too, so imports cannot add case duplicates
    add_check_constraint :users, "email_address = lower(email_address)", name: "users_email_address_lowercase"

    # The inbox and the feedback list read the newest page, not the whole account
    add_index :insights, [ :account_id, :triage_state, :created_at, :id ], order: { created_at: :desc, id: :desc },
              name: "index_insights_for_inbox"
    add_index :feedback_notes, [ :account_id, :created_at, :id ], order: { created_at: :desc, id: :desc },
              name: "index_feedback_notes_for_list"
  end
end
