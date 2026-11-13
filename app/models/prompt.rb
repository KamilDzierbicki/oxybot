# The model instructions, in Langfuse's text-prompt format ({{variable}}). With Langfuse configured, the version
# labeled "production" is used, so prompts change without a deploy; the files in config/prompts are the fallback
# when Langfuse is not set up or cannot be reached, and the source for `bin/rails langfuse:push_prompts`.
class Prompt
  NAMES = %w[insight-extractor feature-judge product-agent document-writer document-reviser].freeze
  LABEL = "production"
  CACHE_TTL = 5.minutes
  FILES = Rails.root.join("config/prompts")

  Template = Data.define(:name, :text, :source, :version)

  def self.render(name, **variables)
    template = fetch(name)
    text = template.text.gsub(/\{\{\s*(\w+)\s*\}\}/) { variables.fetch($1.to_sym, "").to_s.strip }
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  def self.fetch(name)
    raise ArgumentError, "unknown prompt #{name}" unless NAMES.include?(name)
    return from_file(name) unless Prompt::Langfuse.configured?

    # Only successes are cached: after a failure the next call tries Langfuse again, using the file meanwhile
    Rails.cache.read(cache_key(name)) || Prompt::Langfuse.fetch(name, label: LABEL).tap { |template| Rails.cache.write(cache_key(name), template, expires_in: CACHE_TTL) }
  rescue Prompt::Langfuse::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    Rails.logger.warn("[prompt] #{name}: #{e.message}; using config/prompts")
    from_file(name)
  end

  def self.from_file(name)
    Template.new(name: name, text: FILES.join("#{name}.txt").read, source: "file", version: nil)
  end

  def self.refresh
    NAMES.each { |name| Rails.cache.delete(cache_key(name)) }
  end

  def self.cache_key(name) = "prompt/#{name}/#{LABEL}"

  # For trace metadata: which prompt version produced an answer
  def self.version_tag(name)
    template = fetch(name)
    template.version ? "#{name}@v#{template.version}" : "#{name}@file"
  end
end
