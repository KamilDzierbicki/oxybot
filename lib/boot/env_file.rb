# Reads KEY=value lines from .env before Rails boots, for bin/dev and the rake tasks that talk to LiteLLM and
# Langfuse. Variables already set in the shell win, and comments and empty values are skipped. Loaded before
# Rails, so it is not autoloaded (config.autoload_lib ignores lib/boot).
module EnvFile
  def self.load(path, env: ENV)
    return unless File.exist?(path)

    File.foreach(path) do |line|
      key, value = line.strip.split("=", 2)
      next if key.nil? || key.start_with?("#") || value.nil? || value.empty?

      env[key] ||= value
    end
  end
end
