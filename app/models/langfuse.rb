# Langfuse's public API (basic auth with the project's public and secret key): prompts, skills and scores.
module Langfuse
  class Error < StandardError; end

  module_function

  def configured?
    ENV["LANGFUSE_URL"].present? && ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  end

  def environment = Otel.environment

  def get(path) = request(Net::HTTP::Get, path)
  def post(path, payload) = request(Net::HTTP::Post, path, payload)

  # Deleting what is already gone is fine
  def delete(path)
    request(Net::HTTP::Delete, path)
  rescue Error => e
    raise unless e.message.include?("answered 404")
  end

  # Runs the block in a named span, the root of a Langfuse trace, and yields the trace id so a person's later
  # decision can be scored on exactly this call. Yields nil when tracing is off.
  # langfuse.trace.name: Langfuse v4 does not derive the trace name from the root span, and evaluation rules select
  # traces by it
  def traced(name)
    OpenTelemetry.tracer_provider.tracer("oxybot").in_span(name, attributes: { "langfuse.trace.name" => name }) do |span|
      yield(span.context.valid? ? span.context.hex_trace_id : nil, span)
    end
  end

  # What the evaluators read on a root span: input, output and extra context. Written only when OXYBOT_TRACE_CONTENT
  # is on, because it holds customer feedback.
  def record_content(span, input:, output:, metadata: {})
    return unless Rails.configuration.x.trace_content && span&.context&.valid?

    span.set_attribute("langfuse.observation.input", input.to_json)
    span.set_attribute("langfuse.observation.output", output.to_json)
    metadata.each { |key, value| span.set_attribute("langfuse.observation.metadata.#{key}", value.to_json) }
  end

  def request(method, path, payload = nil)
    uri = URI("#{ENV.fetch("LANGFUSE_URL")}#{path}")
    request = method.new(uri, "Content-Type" => "application/json")
    request.basic_auth(ENV.fetch("LANGFUSE_PUBLIC_KEY"), ENV.fetch("LANGFUSE_SECRET_KEY"))
    request.body = payload.to_json if payload
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5) { |http| http.request(request) }
    raise Error, "Langfuse #{path} answered #{response.code}: #{response.body.to_s.truncate(300)}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
