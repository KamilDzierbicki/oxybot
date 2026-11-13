class ReviseDocumentJob < ApplicationJob
  queue_as :assistant

  def perform(suggestion) = suggestion.generate
end
