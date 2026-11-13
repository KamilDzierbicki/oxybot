# Writes product documents from a brief that code assembled. It may search feedback and the codebase for more;
# it has no tool that changes anything.
class DocumentWriter < RubyLLM::Agent
  model provider: :openai, protocol: :chat_completions, assume_model_exists: true do
    generation.account.ai_model("writer")
  end
  inputs :generation
  instructions { Prompt.render("document-writer", **Prompt::Context.new(generation.account, generation.user).to_h) }
  tools do
    tools = [ SearchFeedbackTool.new(generation) ]
    tools += [ SearchCodeTool.new(generation), ReadFileTool.new(generation) ] if generation.account.github_integration
    tools
  end
  tool_options { { rounds: generation.account.ai_setting("agent_max_rounds") } }
  provider_options { { user: "account-#{generation.account.id}", metadata: generation.trace_metadata } }
end
