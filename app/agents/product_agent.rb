# The product assistant. It answers from the tenant's feedback through read-only tools; it has no tool that
# changes data or reaches outside the app, because feedback text is written by outsiders.
class ProductAgent < RubyLLM::Agent
  model "flint-assistant", provider: :openai, protocol: :chat_completions, assume_model_exists: true
  inputs :turn
  instructions do
    RubyLLM.render_prompt("product_agent/instructions",
                          account: turn.account, user: turn.user, revenue_visible: turn.revenue_visible?)
  end
  tools { [ SearchFeedbackTool.new(turn), FeatureDemandTool.new(turn), ListFeaturesTool.new(turn) ] }
  tool_options rounds: Conversation::Turn::MAX_TOOL_ROUNDS
  # LiteLLM counts spend per end user, so each tenant's cost is visible and can get its own budget
  end_user { "account-#{turn.account.id}" }
  provider_options { { metadata: turn.trace_metadata } }
end
