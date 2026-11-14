# Product usage for launch reviews: weekly users of the feature's analytics key before and after its release, from
# Amplitude or Pendo, and a link to a fresh run of the team's Hex launch analysis when Hex is connected (Hex's API
# cannot return numbers). Without these, the review says what to measure.
class Feature::UsageMetrics
  def self.for(feature)
    return unless feature.released_at

    integrations = feature.account.integrations.to_a
    analytics = integrations.find(&:analytics?) if feature.analytics_key.present?
    hex = integrations.find { |integration| integration.is_a?(Integration::Hex) }
    usage = analytics && new(feature, analytics).summary
    hex_line = hex_link(hex, feature)
    return usage unless hex_line

    usage ? usage.merge(lines: usage[:lines] + [ hex_line ]) : { source: "Hex", lines: [ hex_line ] }
  end

  def self.hex_link(hex, feature)
    url = hex&.launch_run_url(feature)
    "- Full launch analysis in Hex (a new run with this feature and release date): #{url}" if url
  rescue Integration::Http::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    "- The Hex launch analysis could not be started (#{e.message.truncate(100)})."
  end

  def initialize(feature, integration)
    @feature = feature
    @integration = integration
  end

  def summary
    weeks = @integration.weekly_usage(@feature)
    released = @feature.released_at.to_date.beginning_of_week
    before, after = weeks.partition { |week| week[:week] < released }
    { source: source, lines: [ line("before the release", before), line("since the release", after), change(before, after) ].compact }
  rescue Integration::Http::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    { source: source, lines: [ "- Usage data could not be read (#{e.message.truncate(120)}); say what to measure instead." ] }
  end

  private

  def source
    name = "#{@integration.display_name}, “#{@feature.analytics_key}”"
    @integration.mock? ? "#{name} (test mode: sample numbers, not real usage)" : name
  end

  def line(label, weeks)
    return "- Weekly users #{label}: no data" if weeks.empty?

    "- Weekly users #{label}: #{weeks.map { |week| "#{week[:week].to_fs(:short)} #{week[:users]}" }.join(", ")} (average #{average(weeks)})"
  end

  def change(before, after)
    return if before.empty? || after.empty? || average(before).zero?

    "- Change in average weekly users: #{((average(after) - average(before)) * 100.0 / average(before)).round}%"
  end

  def average(weeks) = (weeks.sum { |week| week[:users] }.to_f / weeks.size).round
end
