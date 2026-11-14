# The model instructions, in Langfuse's text-prompt format ({{variable}}). With Langfuse configured, the version
# labeled "production" is used, so prompts change without a deploy; the files in config/prompts are the fallback
# when Langfuse is not set up or cannot be reached, and the source for `bin/rails langfuse:push_prompts`.
class Prompt
  NAMES = %w[insight-extractor feature-judge product-agent document-writer document-reviser].freeze
  LABEL = "production"
  CACHE_TTL = 5.minutes
  FILES = Rails.root.join("config/prompts")
  UNREACHABLE_KEY = "prompt/langfuse-unreachable"

  Template = Data.define(:name, :text, :source, :version)

  # Separates the part of a prompt that is the same on every call (cached by the provider) from what changes per call
  PER_REQUEST = /^--- per request ---$/

  def self.render(name, **variables)
    template = fetch(name)
    text = template.text.gsub(/\{\{\s*(\w+)\s*\}\}/) { variables.fetch($1.to_sym, "").to_s.strip }
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  # [stable, per_request]: two system messages, so the provider caches the first however the second changes.
  # A prompt version without the marker is all stable.
  def self.render_parts(name, **variables) = split_parts(render(name, **variables))

  def self.split_parts(text)
    stable, per_request = text.split(PER_REQUEST, 2)
    [ stable.to_s.strip, per_request.to_s.strip ]
  end

  def self.fetch(name)
    raise ArgumentError, "unknown prompt #{name}" unless NAMES.include?(name)
    return from_file(name) unless Prompt::Langfuse.configured?
    # After a failure, skip Langfuse for a minute so one outage does not slow every request
    return from_file(name) if Rails.cache.read(UNREACHABLE_KEY)

    # Only successes are cached: after a failure the next call tries Langfuse again, using the file meanwhile
    Rails.cache.read(cache_key(name)) || Prompt::Langfuse.fetch(name, label: LABEL).tap { |template| Rails.cache.write(cache_key(name), template, expires_in: CACHE_TTL) }
  rescue Prompt::Langfuse::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    Rails.logger.warn("[prompt] #{name}: #{e.message}; using config/prompts")
    Rails.cache.write(UNREACHABLE_KEY, true, expires_in: 1.minute)
    from_file(name)
  end

  # Model calls in the block are linked to the Langfuse version of this prompt; a file prompt has no version to link
  def self.linked(name, &block)
    version = fetch(name).version
    return block.call unless version

    OpenTelemetry::Context.with_value(Otel::PROMPT, { name: name, version: version }, &block)
  end

  def self.from_file(name)
    Template.new(name: name, text: FILES.join("#{name}.txt").read, source: "file", version: nil)
  end

  def self.refresh
    Rails.cache.delete(UNREACHABLE_KEY)
    NAMES.each { |name| Rails.cache.delete(cache_key(name)) }
  end

  def self.cache_key(name) = "prompt/#{name}/#{LABEL}"

  # For trace metadata: which prompt version produced an answer
  def self.version_tag(name)
    template = fetch(name)
    template.version ? "#{name}@v#{template.version}" : "#{name}@file"
  end
end
