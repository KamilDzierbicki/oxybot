class MessagesController < ApplicationController
  def create
    @conversation = Current.user.conversations.find(params[:conversation_id])
    @conversation.ask(params.expect(:question))

    respond_to do |format|
      # Both messages arrive through the conversation's Turbo Stream; only the form is reset here
      format.turbo_stream { render turbo_stream: turbo_stream.replace("message_form", partial: "messages/form", locals: { conversation: @conversation }) }
      format.html { redirect_to @conversation }
    end
  end
end
