# The model instructions, in Langfuse's text-prompt format ({{variable}}). With Langfuse configured, the version
# labeled "production" is used, so prompts change without a deploy; the files in config/prompts are the fallback
# when Langfuse is not set up or cannot be reached, and the source for `bin/rails langfuse:push_prompts`.
#
# Each version also carries a config (Langfuse's prompt config, config/prompts/<name>.yml as the file side): the
# assistant's tool descriptions and the retrieval parameters, so they change, are compared and roll out together
# with the prompt text. Prompt.using picks another version or label for a block, for experiments and rollouts.
class Prompt
  NAMES = %w[insight-extractor feature-judge product-agent document-writer document-reviser].freeze
  LABEL = "production"
  CACHE_TTL = 5.minutes
  FILES = Rails.root.join("config/prompts")
  UNREACHABLE_KEY = "prompt/langfuse-unreachable"

  Template = Data.define(:name, :text, :source, :version, :config) do
    def initialize(name:, text:, source:, version:, config: {}) = super
  end

  STATE = :oxybot_prompt_variant
  # Retrieval parameters a config may set, with their allowed range; anything else is ignored, so a typo in
  # Langfuse cannot switch search off. limit: results returned, candidates: per search list before fusion,
  # rrf_k: reciprocal rank fusion constant, weights: how much each list counts in the fusion
  RETRIEVAL = { "limit" => 1..50, "candidates" => 1..100, "rrf_k" => 1..1000, "vector_weight" => 0.0..10.0, "text_weight" => 0.0..10.0 }.freeze

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

  # Inside the block the named prompts use another version: a label ("candidate") or a version number; the others
  # stay on production. retrieval: overrides for every retrieval config, for experiments ("rrf_k" => 30).
  def self.using(versions = {}, retrieval: {})
    previous = variant
    ActiveSupport::IsolatedExecutionState[STATE] = { versions: previous[:versions].merge(versions.transform_keys(&:to_s)),
                                                     retrieval: previous[:retrieval].merge(retrieval.transform_keys(&:to_s)) }
    yield
  ensure
    ActiveSupport::IsolatedExecutionState[STATE] = previous
  end

  def self.variant = ActiveSupport::IsolatedExecutionState[STATE] || { versions: {}, retrieval: {} }

  # The label or version this prompt uses right now
  def self.selected(name) = variant[:versions].fetch(name, LABEL)

  def self.fetch(name)
    raise ArgumentError, "unknown prompt #{name}" unless NAMES.include?(name)
    return from_file(name) unless Prompt::Langfuse.configured?
    # After a failure, skip Langfuse for a minute so one outage does not slow every request
    return from_file(name) if Rails.cache.read(UNREACHABLE_KEY)

    # Only successes are cached: after a failure the next call tries Langfuse again, using the file meanwhile
    choice = selected(name)
    Rails.cache.read(cache_key(name, choice)) ||
      Prompt::Langfuse.fetch(name, choice).tap { |template| Rails.cache.write(cache_key(name, choice), template, expires_in: CACHE_TTL) }
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
    Template.new(name: name, text: FILES.join("#{name}.txt").read, source: "file", version: nil, config: file_config(name))
  end

  def self.file_config(name)
    path = FILES.join("#{name}.yml")
    path.exist? ? YAML.load_file(path) : {}
  end

  # The version's config over the file's, so a version saved before a key existed still gets it
  def self.config(name)
    config = file_config(name).deep_merge(fetch(name).config || {})
    config["retrieval"] = config["retrieval"].merge(variant[:retrieval]) if config["retrieval"].is_a?(Hash)
    config
  end

  # The retrieval parameters of this prompt's config. A value outside RETRIEVAL's range is replaced by the file's.
  def self.retrieval(name)
    file = file_config(name).fetch("retrieval", {})
    config(name).fetch("retrieval", {}).each_with_object({}) do |(key, value), valid|
      number = retrieval_value(key, value)
      Rails.logger.warn("[prompt] #{name}: ignored retrieval #{key}=#{value.inspect}") if number.nil?
      number ||= retrieval_value(key, file[key])
      valid[key] = number if number
    end
  end

  def self.retrieval_value(key, value)
    range = RETRIEVAL[key] or return
    number = range.begin.is_a?(Integer) ? Integer(value, exception: false) : Float(value, exception: false)
    number if number && range.cover?(number)
  end

  def self.refresh
    Rails.cache.delete(UNREACHABLE_KEY)
    NAMES.each { |name| Rails.cache.delete(cache_key(name, LABEL)) }
  end

  def self.cache_key(name, choice) = "prompt/#{name}/#{choice}"

  # For trace metadata: which prompt version produced an answer
  def self.version_tag(name)
    template = fetch(name)
    template.version ? "#{name}@v#{template.version}" : "#{name}@file"
  end
end
