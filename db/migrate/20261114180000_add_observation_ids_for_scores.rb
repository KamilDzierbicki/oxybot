# The model call (Langfuse observation) a person's decision is scored on, next to its trace id: scores on that call
# can be split by the prompt version and model it carries
class AddObservationIdsForScores < ActiveRecord::Migration[8.1]
  def change
    add_column :insights, :match_observation_id, :string
    add_column :feedback_notes, :extraction_observation_id, :string
    add_column :document_suggestions, :observation_id, :string
  end
end
