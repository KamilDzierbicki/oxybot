class LangfuseScoreJob < ApplicationJob
  queue_as :default
  retry_on Langfuse::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 5

  def perform(id, payload)
    payload ? Langfuse.post("/api/public/scores", payload.merge("id" => id)) : Langfuse.delete("/api/public/scores/#{ERB::Util.url_encode(id)}")
  end
end
