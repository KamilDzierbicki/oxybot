# Evaluation cases learned from people's corrections: when a product manager links another feature than the one the
# judge suggested, the need and the right feature become a matching case, reviewed before experiments use it
class CreateEvaluationCases < ActiveRecord::Migration[8.1]
  def change
    create_table :evaluation_cases do |t|
      t.references :account, null: false, foreign_key: true
      t.references :insight, foreign_key: { on_delete: :nullify }
      t.references :reviewed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :task, null: false
      t.jsonb :input, null: false, default: {}
      t.jsonb :expected, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :evaluation_cases, [ :insight_id, :task ], unique: true, where: "insight_id IS NOT NULL"
    add_index :evaluation_cases, [ :account_id, :task, :status ]
    add_check_constraint :evaluation_cases, "status IN ('pending', 'approved', 'rejected')", name: "evaluation_cases_status"
  end
end
