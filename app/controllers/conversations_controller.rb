class ConversationsController < ApplicationController
  include Paginated
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 20, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  def index
    @conversations = paginate(Current.user.conversations.latest_first)
  end

  def show
    @conversation = Current.user.conversations.find(params[:id])
  end

  def create
    question = params.expect(:question).to_s.strip
    return redirect_to(conversations_path, alert: "Type a question first.") if question.blank?

    conversation = Current.user.conversations.create!(account: Current.account, channel: "web")
    conversation.ask(question)
    redirect_to conversation
  end
end
