# Amplitude Dashboard REST API, Event Segmentation (https://amplitude.com/docs/apis/analytics/dashboard-rest):
# GET /api/2/events/segmentation with basic auth (API key, secret key). i=7 gives weekly buckets of distinct users.
class Integration::Amplitude::Client
  HOSTS = { "us" => "https://amplitude.com", "eu" => "https://analytics.eu.amplitude.com" }.freeze

  def initialize(api_key, secret_key, region)
    @auth = Integration::Http.basic(api_key, secret_key)
    @host = HOSTS.fetch(region.presence || "us")
  end

  def weekly_users(event, from:, to:)
    body = Integration::Http.get("#{@host}/api/2/events/segmentation", headers: @auth, params: {
      e: { event_type: event }.to_json, m: "uniques", i: 7, start: from.strftime("%Y%m%d"), end: to.strftime("%Y%m%d")
    })
    data = body.fetch("data")
    data.fetch("xValues").zip(data.fetch("series").first || []).map { |day, users| { week: Date.parse(day), users: users.to_i } }
  end
end
