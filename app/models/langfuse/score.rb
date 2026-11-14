# A person's decision on a model's output, sent to Langfuse as a 0/1 score on the trace of that model call: linking the
# suggested feature, dismissing an insight, accepting a document suggestion. Only the score name and value leave OxyBot,
# never text. Ids are fixed per decision, so a changed decision overwrites its score and an undo removes it.
module Langfuse::Score
  module_function

  def record(id, trace_id:, name:, value:)
    return if trace_id.blank? || !Langfuse.configured?

    LangfuseScoreJob.perform_later(id, { "traceId" => trace_id, "name" => name, "value" => value ? 1 : 0, "dataType" => "BOOLEAN" })
  end

  def remove(id)
    LangfuseScoreJob.perform_later(id, nil) if Langfuse.configured?
  end
end
