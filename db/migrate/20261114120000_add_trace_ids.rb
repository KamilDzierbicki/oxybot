# The Langfuse trace of the model call behind a record, so a person's later decision can be scored on that call
class AddTraceIds < ActiveRecord::Migration[8.1]
  def change
    add_column :insights, :match_trace_id, :string
    add_column :feedback_notes, :extraction_trace_id, :string
    add_column :document_suggestions, :trace_id, :string
  end
end
