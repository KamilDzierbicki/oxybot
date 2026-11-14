# The production version a promotion replaced, so prompts:rollback can restore it
class AddPreviousVersionToPromptRollouts < ActiveRecord::Migration[8.1]
  def change
    add_column :prompt_rollouts, :previous_version, :integer
  end
end
