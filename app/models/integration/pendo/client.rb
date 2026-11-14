# Pendo Aggregation API (https://engageapi.pendo.io/): POST /api/v1/aggregation with the x-pendo-integration-key
# header. featureEvents rows are pre-grouped per visitor and day; counting distinct visitorId per week gives
# weekly unique users. Pendo's weeks start on Sunday; the week is reported by its Monday.
class Integration::Pendo::Client
  def initialize(key, host)
    @headers = { "x-pendo-integration-key" => key.to_s }
    @base = "https://#{Integration::Pendo::HOSTS.include?(host) ? host : "app.pendo.io"}"
  end

  def verify = Integration::Http.get("#{@base}/api/v1/token/verify", headers: @headers)

  def weekly_users(feature_id, from:, to:)
    pipeline = [
      { source: { featureEvents: { featureId: feature_id },
                  timeSeries: { period: "dayRange", first: from.to_time.to_i * 1000, last: (to + 1).to_time.to_i * 1000 - 1 } } },
      { identified: "visitorId" },
      { group: { group: [ "week" ], fields: { users: { count: "visitorId" } } } },
      { sort: [ "week" ] }
    ]
    body = Integration::Http.post("#{@base}/api/v1/aggregation", { response: { mimeType: "application/json" }, request: { pipeline: pipeline } },
                                  headers: @headers)
    body.fetch("results").map { |row| { week: Time.at(row.fetch("week") / 1000).utc.to_date.beginning_of_week, users: row.fetch("users").to_i } }
  end
end
