# The product assistant. It answers from the tenant's feedback through read-only tools; it has no tool that
# changes data or reaches outside the app, because feedback text is written by outsiders.
class ProductAgent < RubyLLM::Agent
  model provider: :openai, protocol: :chat_completions, assume_model_exists: true do
    turn.account.ai_model("assistant")
  end
  max_output_tokens 1500
  inputs :turn
  # Two system messages: the stable part first, so LiteLLM's cache mark makes later calls read it from the cache
  instructions { turn.system_prompt.first }
  instructions(append: true) { turn.system_prompt.last.presence }
  tools do
    tools = [ SearchFeedbackTool.new(turn), FeatureDemandTool.new(turn), ListFeaturesTool.new(turn) ]
    tools << SearchKnowledgeTool.new(turn) if turn.account.knowledge_chunks.exists?
    tools
  end
  tool_options { { rounds: turn.account.ai_setting("agent_max_rounds") } }
  # LiteLLM counts spend per end user, so each tenant's cost is visible and can get its own budget
  provider_options { { user: "account-#{turn.account.id}", metadata: turn.trace_metadata } }
end
