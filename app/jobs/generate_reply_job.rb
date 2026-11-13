class GenerateReplyJob < ApplicationJob
  queue_as :assistant

  def perform(message) = message.generate
end
