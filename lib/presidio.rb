require "net/http"
require "json"

# Presidio's REST API (compose.yml): /analyze finds personal data in a text, /anonymize replaces each finding with
# its type (<PERSON>, <EMAIL_ADDRESS>, <PHONE_NUMBER>). Plain Ruby in lib, because the trace exporter calls it from
# its own thread at any time, outside Rails' code reloading.
module Presidio
  Error = Class.new(StandardError)

  module_function

  def mask(text)
    findings = post(ENV.fetch("PRESIDIO_ANALYZER_URL", "http://localhost:5012"), "/analyze", { text: text, language: ENV.fetch("PRESIDIO_LANGUAGE", "en") })
    return text if findings.empty?

    post(ENV.fetch("PRESIDIO_ANONYMIZER_URL", "http://localhost:5011"), "/anonymize", { text: text, analyzer_results: findings }).fetch("text")
  end

  def post(base_url, path, body)
    uri = URI("#{base_url}#{path}")
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 10) do |http|
      http.post(uri.path, body.to_json, "Content-Type" => "application/json")
    end
    raise Error, "Presidio #{path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
    raise Error, "Presidio #{path} failed: #{e.class}"
  end
end
