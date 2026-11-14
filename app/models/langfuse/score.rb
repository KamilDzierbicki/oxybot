# A person's decision on a model's output, sent to Langfuse as a 0/1 score on the trace of that model call: linking the
# suggested feature, dismissing an insight, accepting a document suggestion. Only the score name and value leave OxyBot,
# never text. Ids are fixed per decision, so a changed decision overwrites its score and an undo removes it.
module Langfuse::Score
  module_function

  # observation_id: the model call within the trace, so Langfuse can split the score by its prompt version and model
  def record(id, trace_id:, observation_id:, name:, value:)
    return if trace_id.blank? || !Langfuse.configured?

    LangfuseScoreJob.perform_later(id, { "traceId" => trace_id, "observationId" => observation_id, "name" => name, "value" => value ? 1 : 0,
                                         "dataType" => "BOOLEAN", "environment" => Langfuse.environment }.compact)
  end

  def remove(id)
    LangfuseScoreJob.perform_later(id, nil) if Langfuse.configured?
  end
end
