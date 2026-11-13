# One assistant turn: replays the conversation to the product agent, lets it call its tools, then stores the
# answer. Tools report every insight they returned, so the answer may only cite insights the model really saw.
class Conversation::Turn
  include CitationTracking

  attr_reader :reply, :conversation

  delegate :account, :user, :revenue_visible?, to: :conversation

  def initialize(reply)
    @reply = reply
    @conversation = reply.conversation
    @tool_calls = []
  end

  def run
    agent = ProductAgent.new(turn: self)
    history.each { |message| agent.add_message(role: message.role.to_sym, content: message.content) }
    agent.before_tool_call { |call| @tool_calls << { name: call.name, arguments: call.arguments } }

    response = agent.ask(question_text)
    content, cited = checked_citations(response.content.to_s)
    reply.update!(status: "done", content: content.presence || "(no answer)", tool_calls: @tool_calls,
                  cited_insight_ids: cited, input_tokens: response.tokens&.input, output_tokens: response.tokens&.output)
    deliver_to_chat
  rescue RubyLLM::Error, RubyLLM::ToolRoundLimitError, Faraday::Error => e
    Rails.error.report(e, context: { message_id: reply.id })
    reply.update!(status: "failed", content: "Sorry, I could not answer this time (#{e.class.name.demodulize}). Try again in a moment.",
                  tool_calls: @tool_calls)
    deliver_to_chat
  end

  # Grouped in Langfuse by conversation (session) and tagged with the tenant
  def trace_metadata
    { session_id: "conversation-#{conversation.id}", trace_user_id: "user-#{user.id}",
      tags: [ "account-#{account.id}", "channel-#{conversation.channel}", Prompt.version_tag("product-agent") ], generation_name: "product-agent" }
  end

  def prompt_variables
    Prompt::Context.new(account, user).to_h.merge(
      revenue_rule: revenue_visible? ? "" : "This answer is posted in a shared Slack channel. Do not mention revenue, ARR or contract values; counts of customers are fine.",
      skill: skill ? "The user ran the \"/#{skill.name}\" skill (#{skill.description}). Follow it for this answer:\n#{skill.instructions.strip}" : ""
    )
  end

  # "/voc reporting" runs the voc skill with "reporting" as the request
  def skill
    invocation&.first
  end

  private

  def invocation
    return @invocation if defined?(@invocation)

    @invocation = Skill.invoked_in(question.content, user)
  end

  def question_text
    return question.content unless invocation

    invocation.last.presence || "Run the #{skill.name} skill."
  end

  def question
    @question ||= conversation.messages.where(role: "user").where(id: ...reply.id).last
  end

  def history
    conversation.messages.where(status: "done").where(id: ...question.id)
  end

  def deliver_to_chat
    conversation.integration&.post_reply(conversation, reply)
  end
end
