class MessagesController < ApplicationController
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 20, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  def create
    @conversation = Current.user.conversations.find(params[:conversation_id])
    question = params.expect(:question).to_s.strip
    return redirect_to(@conversation, alert: "Type a question first.") if question.blank?

    @conversation.ask(question)

    respond_to do |format|
      # Both messages arrive through the conversation's Turbo Stream; the form clears itself and keeps focus
      format.turbo_stream { head :no_content }
      format.html { redirect_to @conversation }
    end
  end
end
