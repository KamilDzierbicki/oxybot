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
    # A retried or recovered job must not answer (and post to chat, and pay the model) twice
    return unless reply.with_lock { reply.thinking? && reply.update!(status: "thinking", updated_at: Time.current) }
    return paused unless Rails.configuration.x.ai_enabled

    agent = ProductAgent.new(turn: self)
    history.each { |message| agent.add_message(role: message.role.to_sym, content: message.content) }
    # In the web app the answer appears while it is written; Slack and Mattermost get the finished answer
    stream = Conversation::Stream.new(reply) if conversation.channel == "web"
    agent.before_tool_call do |call|
      @tool_calls << { name: call.name, arguments: call.arguments }
      stream&.restart
    end

    Langfuse.traced("assistant-turn", account: account, conversation_id: conversation.id, message_id: reply.id,
                    oxybot_url: Langfuse.url(conversation, anchor: "message_#{reply.id}")) do |trace|
      response = Skill::Tracing.with(available: Skill.available_to(user), used: skill) { Prompt.linked("product-agent") { agent.ask(question_text, &stream) } }
      content, cited = checked_citations(response.content.to_s)
      reply.update!(status: "done", content: content.presence || "(no answer)", tool_calls: @tool_calls,
                    cited_insight_ids: cited, input_tokens: response.tokens&.input, output_tokens: response.tokens&.output)
      # The evaluator checks the answer against what the tools returned for the cited insights: quote and customer record
      Langfuse.record_content(trace.span, input: question_text, output: reply.content, metadata: { evidence: evidence_for(cited) })
    end
    deliver_to_chat
  rescue RubyLLM::Error, RubyLLM::ToolRoundLimitError, Faraday::Error => e
    Rails.error.report(e, context: { message_id: reply.id })
    message = LiteLlm.budget_exceeded?(e) ? LiteLlm::BUDGET_MESSAGE : "Sorry, I could not answer this time (#{e.class.name.demodulize}). Try again in a moment."
    reply.update!(status: "failed", content: message, tool_calls: @tool_calls)
    deliver_to_chat
  end

  # Grouped in Langfuse by conversation (session) and tagged with the tenant
  def trace_metadata
    { session_id: "conversation-#{conversation.id}", trace_user_id: "user-#{user.id}",
      tags: [ "account-#{account.id}", "channel-#{conversation.channel}", Prompt.version_tag("product-agent"), ("skill-#{skill.name}" if skill) ].compact,
      generation_name: "product-agent" }
  end

  def system_prompt
    @system_prompt ||= Prompt.render_parts("product-agent", **prompt_variables)
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

  def evidence_for(insight_ids)
    account.insights.includes(:customer).where(id: insight_ids).map do |insight|
      customer = insight.customer
      { id: insight.id, quote: insight.quote, urgency: insight.urgency,
        customer: customer && { name: customer.name, plan: customer.plan, arr: customer.arr_cents / 100 } }
    end
  end

  def paused
    reply.update!(status: "failed", content: "AI answers are paused on this server. Try again later.")
    deliver_to_chat
  end

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
