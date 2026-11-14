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

  # The root span of an OxyBot trace. id and generation_id (its last model call) let a person's later decision be
  # scored on exactly this call; both are nil when tracing is off.
  Trace = Struct.new(:id, :span, :generation_id)

  # Runs the block in a named span, the root of a Langfuse trace, and yields the Trace.
  # langfuse.trace.name: Langfuse v4 does not derive the trace name from the root span, and evaluation rules select
  # traces by it. ids: record ids and an oxybot_url link, never text, as filterable trace metadata, so a reviewer
  # in Langfuse finds the record in OxyBot. account: the workspace whose request this is; prompt rollouts
  # (PromptRollout) pick its prompt versions here, and prompt_variant names the candidates it got.
  def traced(name, account:, **ids)
    versions = PromptRollout.versions_for(account)
    ids[:prompt_variant] = versions.map { |prompt, label| "#{prompt}@#{label}" }.join(",").presence
    attributes = { "langfuse.trace.name" => name }
    ids.compact.each { |key, value| attributes["langfuse.trace.metadata.#{key}"] = value.to_s }
    Prompt.using(versions) do
      OpenTelemetry.tracer_provider.tracer("oxybot").in_span(name, attributes: attributes) do |span|
        trace = Trace.new(span.context.valid? ? span.context.hex_trace_id : nil, span)
        OpenTelemetry::Context.with_value(Otel::TRACE, trace) { yield trace }
      end
    end
  end

  # The absolute OxyBot link to a record, for trace metadata
  def url(record, **options)
    Rails.application.routes.url_helpers.polymorphic_url(record, **Rails.application.config.x.url_options, **options)
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
