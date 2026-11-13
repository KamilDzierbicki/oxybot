# Writes product documents from a brief that code assembled. It may search feedback and the codebase for more;
# it has no tool that changes anything.
class DocumentWriter < RubyLLM::Agent
  model "openspark-writer", provider: :openai, protocol: :chat_completions, assume_model_exists: true
  inputs :generation
  instructions { RubyLLM.render_prompt("document_writer/instructions", account: generation.account, user: generation.user) }
  tools do
    tools = [ SearchFeedbackTool.new(generation) ]
    tools += [ SearchCodeTool.new(generation), ReadFileTool.new(generation) ] if generation.account.github_integration
    tools
  end
  tool_options rounds: 6
  end_user { "account-#{generation.account.id}" }
  provider_options { { metadata: generation.trace_metadata } }
end
