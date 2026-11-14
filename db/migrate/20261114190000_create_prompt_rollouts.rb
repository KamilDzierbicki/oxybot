# A gradual rollout of a prompt version: the share of workspaces (or requests) that get the version with this
# Langfuse label instead of production
class CreatePromptRollouts < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_rollouts do |t|
      t.string :prompt_name, null: false
      t.string :label, null: false, default: "candidate"
      t.integer :share, null: false, default: 0
      t.string :unit, null: false, default: "workspace"
      t.timestamps
    end
    add_index :prompt_rollouts, :prompt_name, unique: true
  end
end
