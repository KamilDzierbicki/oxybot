# Langfuse's public API (basic auth with the project's public and secret key): prompts, skills and scores.
module Langfuse
  class Error < StandardError; end

  module_function

  def configured?
    ENV["LANGFUSE_URL"].present? && ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  end

  def get(path) = request(Net::HTTP::Get, path)
  def post(path, payload) = request(Net::HTTP::Post, path, payload)

  def request(method, path, payload = nil)
    uri = URI("#{ENV.fetch("LANGFUSE_URL")}#{path}")
    request = method.new(uri, "Content-Type" => "application/json")
    request.basic_auth(ENV.fetch("LANGFUSE_PUBLIC_KEY"), ENV.fetch("LANGFUSE_SECRET_KEY"))
    request.body = payload.to_json if payload
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5) { |http| http.request(request) }
    raise Error, "Langfuse #{path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
