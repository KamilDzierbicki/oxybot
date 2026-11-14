class PublishSkillJob < ApplicationJob
  queue_as :default
  retry_on Langfuse::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError # the skill was deleted in the meantime

  def perform(skill) = Skill::Tracing.publish(skill)
end
