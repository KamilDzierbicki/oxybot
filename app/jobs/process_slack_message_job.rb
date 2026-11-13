class ProcessSlackMessageJob < ApplicationJob
  queue_as :default

  def perform(slack_message) = slack_message.process
end
