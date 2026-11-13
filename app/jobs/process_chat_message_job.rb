class ProcessChatMessageJob < ApplicationJob
  queue_as :default

  def perform(chat_message) = chat_message.process
end
