# With OXYBOT_TRACE_CONTENT=redacted, traces carry prompts and answers with personal data removed: before spans
# leave the app, every content attribute goes through the redactor (Presidio.mask). If it fails, the content is
# dropped and the span still goes: no personal data is ever exported unchecked. Runs in the exporter's background
# thread, so redaction never slows a request. JSON content (messages, tool results) is masked value by value and
# stays valid JSON: a name right after a quote mark ("Anna) is missed when the JSON is masked as one text. Texts
# repeat (the stable part of a prompt), so results are memoized.
module Otel
  class RedactingExporter
    CONTENT = /\A(gen_ai\.(input|output)\.messages|gen_ai\.system_instructions|gen_ai\.tool\.call\.(arguments|result)|langfuse\.observation\.(input|output|metadata\..+))\z/
    REMOVED = "[removed: personal data could not be checked]"
    MEMO_SIZE = 500

    def initialize(exporter, redactor, logger: nil)
      @exporter = exporter
      @redactor = redactor
      @logger = logger
      @memo = {}
    end

    def export(spans, timeout: nil)
      @exporter.export(spans.map { |span| redact(span) }, timeout: timeout)
    end

    def force_flush(timeout: nil) = @exporter.force_flush(timeout: timeout)
    def shutdown(timeout: nil) = @exporter.shutdown(timeout: timeout)

    private

    def redact(span)
      return span unless span.attributes&.any? { |key, value| value.is_a?(String) && CONTENT.match?(key) }

      copy = span.dup
      copy.attributes = span.attributes.to_h { |key, value| [ key, value.is_a?(String) && CONTENT.match?(key) ? content(value) : value ] }.freeze
      copy
    end

    def content(value)
      parsed = begin
        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end
      parsed.nil? ? masked(value) : JSON.generate(deep_mask(parsed))
    rescue StandardError => e
      @logger&.warn("[trace] content dropped, redaction failed: #{e.class}: #{e.message}")
      REMOVED
    end

    def deep_mask(value)
      case value
      when Hash then value.transform_values { |item| deep_mask(item) }
      when Array then value.map { |item| deep_mask(item) }
      when String then masked(value)
      else value
      end
    end

    def masked(text)
      return text if text.length < 3

      key = Digest::SHA256.hexdigest(text)
      return @memo[key] if @memo.key?(key)

      @memo.clear if @memo.size >= MEMO_SIZE
      @memo[key] = @redactor.call(text)
    end
  end
end
