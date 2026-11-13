class ConversationsController < ApplicationController
  def index
    @conversations = Current.user.conversations.latest_first.limit(30)
  end

  def show
    @conversation = Current.user.conversations.find(params[:id])
  end

  def create
    conversation = Current.user.conversations.create!(account: Current.account, channel: "web")
    conversation.ask(params.expect(:question))
    redirect_to conversation
  end
end
