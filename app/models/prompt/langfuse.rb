# Langfuse's public prompt API (basic auth with the project's public and secret key).
module Prompt::Langfuse
  class Error < StandardError; end

  module_function

  def configured?
    ENV["LANGFUSE_URL"].present? && ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  end

  def fetch(name, label:)
    body = request(Net::HTTP::Get, "/api/public/v2/prompts/#{ERB::Util.url_encode(name)}?label=#{ERB::Util.url_encode(label)}")
    raise Error, "#{name} is a #{body["type"]} prompt; OxyBot needs a text prompt" unless body["type"] == "text"

    Prompt::Template.new(name: name, text: body.fetch("prompt"), source: "langfuse", version: body["version"])
  end

  # Creates a new version; with the label it becomes the one OxyBot uses
  def create(name, text, labels:)
    request(Net::HTTP::Post, "/api/public/v2/prompts", { name: name, type: "text", prompt: text, labels: labels })
  end

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
