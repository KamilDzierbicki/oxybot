# Langfuse's public API (basic auth with the project's public and secret key): prompts, skills and scores.
module Langfuse
  class Error < StandardError; end

  module_function

  def configured?
    ENV["LANGFUSE_URL"].present? && ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  end

  def get(path) = request(Net::HTTP::Get, path)
  def post(path, payload) = request(Net::HTTP::Post, path, payload)

  # Deleting what is already gone is fine
  def delete(path)
    request(Net::HTTP::Delete, path)
  rescue Error => e
    raise unless e.message.end_with?("404")
  end

  # Runs the block in a named span, the root of a Langfuse trace, and yields the trace id so a person's later
  # decision can be scored on exactly this call. Yields nil when tracing is off.
  def traced(name)
    OpenTelemetry.tracer_provider.tracer("oxybot").in_span(name) do |span|
      yield(span.context.valid? ? span.context.hex_trace_id : nil)
    end
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
