# LiteLLM's admin API (master key), next to the OpenAI-compatible /v1 endpoints the agents call.
# Not available with the built-in mock model.
module LiteLlm
  class Error < StandardError; end

  module_function

  BUDGET_MESSAGE = "This workspace has used its daily AI budget. An admin can raise it in AI settings; it resets within a day."

  def available? = !Rails.configuration.x.mock_llm

  # LiteLLM answers 429 with type budget_exceeded when a workspace's daily budget is spent; waiting a moment will not help
  def budget_exceeded?(error) = error.message.to_s.match?(/ExceededBudget|budget_exceeded/)

  def get(path) = request(Net::HTTP::Get, path)
  def post(path, payload) = request(Net::HTTP::Post, path, payload)

  def request(method, path, payload = nil)
    uri = URI("#{Rails.configuration.x.llm_url.delete_suffix("/v1")}#{path}")
    request = method.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV.fetch("LITELLM_API_KEY", "sk-oxybot-local")}")
    request.body = payload.to_json if payload
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 10) { |http| http.request(request) }
    raise Error, "LiteLLM #{path} answered #{response.code}: #{response.body.to_s.truncate(300)}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
