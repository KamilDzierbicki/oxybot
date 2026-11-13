# Product usage for launch reviews. No analytics tool is connected yet, so it reads config/mocks/usage.yml
# (shaped like an Amplitude or Pendo export); swap this class for a real connector later.
class Feature::UsageMetrics
  PATH = Rails.root.join("config/mocks/usage.yml")

  def self.for(feature)
    data = File.exist?(PATH) ? YAML.load_file(PATH) : {}
    metrics = data[feature.title]
    return unless metrics

    { source: "mock analytics (config/mocks/usage.yml)", lines: metrics.map { |name, value| "- #{name.humanize}: #{value}" } }
  end
end
