# The product assistant. It answers from the tenant's feedback through read-only tools; it has no tool that
# changes data or reaches outside the app, because feedback text is written by outsiders.
class ProductAgent < RubyLLM::Agent
  model provider: :openai, protocol: :chat_completions, assume_model_exists: true do
    turn.account.ai_model("assistant")
  end
  max_output_tokens 1500
  inputs :turn
  instructions { Prompt.render("product-agent", **turn.prompt_variables) }
  tools { [ SearchFeedbackTool.new(turn), FeatureDemandTool.new(turn), ListFeaturesTool.new(turn) ] }
  tool_options { { rounds: turn.account.ai_setting("agent_max_rounds") } }
  # LiteLLM counts spend per end user, so each tenant's cost is visible and can get its own budget
  provider_options { { user: "account-#{turn.account.id}", metadata: turn.trace_metadata } }
end
