# One assistant turn: replays the conversation to the product agent, lets it call its tools, then stores the
# answer. Tools report every insight they returned, so the answer may only cite insights the model really saw.
class Conversation::Turn
  MAX_TOOL_ROUNDS = 6

  attr_reader :reply, :conversation, :seen_insight_ids

  delegate :account, :user, :revenue_visible?, to: :conversation

  def initialize(reply)
    @reply = reply
    @conversation = reply.conversation
    @seen_insight_ids = Set.new
    @tool_calls = []
  end

  def run
    agent = ProductAgent.new(turn: self)
    history.each { |message| agent.add_message(role: message.role.to_sym, content: message.content) }
    agent.before_tool_call { |call| @tool_calls << { name: call.name, arguments: call.arguments } }

    response = agent.ask(question.content)
    content, cited = checked_citations(response.content.to_s)
    reply.update!(status: "done", content: content.presence || "(no answer)", tool_calls: @tool_calls,
                  cited_insight_ids: cited, input_tokens: response.tokens&.input, output_tokens: response.tokens&.output)
    deliver_to_slack
  rescue RubyLLM::Error, RubyLLM::ToolRoundLimitError, Faraday::Error => e
    Rails.error.report(e, context: { message_id: reply.id })
    reply.update!(status: "failed", content: "Sorry, I could not answer this time (#{e.class.name.demodulize}). Try again in a moment.",
                  tool_calls: @tool_calls)
    deliver_to_slack
  end

  def remember_insights(ids)
    seen_insight_ids.merge(ids)
  end

  # Grouped in Langfuse by conversation (session) and tagged with the tenant
  def trace_metadata
    { session_id: "conversation-#{conversation.id}", trace_user_id: "user-#{user.id}",
      tags: ["account-#{account.id}", "channel-#{conversation.channel}"], generation_name: "product-agent" }
  end

  private

  def question
    @question ||= conversation.messages.where(role: "user").where(id: ...reply.id).last
  end

  def history
    conversation.messages.where(status: "done").where(id: ...question.id)
  end

  # A citation of an insight no tool returned in this turn is invented (or from another tenant): drop it
  def checked_citations(content)
    cited = []
    checked = content.gsub(Message::CITATION) do
      id = $1.to_i
      next "" unless seen_insight_ids.include?(id)

      cited << id
      "[insight:#{id}]"
    end
    [checked.gsub(/ +\n/, "\n").strip, cited.uniq]
  end

  def deliver_to_slack
    return unless conversation.slack?

    account.slack_integration&.post_reply(conversation, reply)
  end
end
