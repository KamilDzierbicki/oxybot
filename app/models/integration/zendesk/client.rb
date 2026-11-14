# Zendesk Support API (https://developer.zendesk.com/api-reference/ticketing/ticket-management/incremental_exports/):
# OAuth client credentials for a 30-minute token, then the cursor-based incremental ticket export. The export has
# no tag filter, so tickets are filtered by tag here; requesters come side-loaded or from show_many.
class Integration::Zendesk::Client
  MAX_PAGES = 20

  def initialize(subdomain, client_id, client_secret, tag:)
    @base = "https://#{subdomain}.zendesk.com"
    @client_id = client_id
    @client_secret = client_secret
    @tag = tag
  end

  def me = Integration::Http.get("#{@base}/api/v2/users/me", headers: headers)

  def feedback_since(time)
    tickets = []
    users = {}
    params = { start_time: [ time.to_i, 2.minutes.ago.to_i ].min, exclude_deleted: true, include: "users" }
    MAX_PAGES.times do
      body = Integration::Http.get("#{@base}/api/v2/incremental/tickets/cursor", headers: headers, params: params)
      tickets.concat(body.fetch("tickets", []).select { |ticket| ticket["tags"].to_a.include?(@tag) })
      body.fetch("users", []).each { |user| users[user["id"]] = user }
      break if body["end_of_stream"] || body["after_cursor"].blank?

      params = { cursor: body["after_cursor"] }
    end
    missing = tickets.map { |ticket| ticket["requester_id"] }.uniq - users.keys
    users_by_id(missing).each { |user| users[user["id"]] = user } if missing.any?
    tickets.map { |ticket| item(ticket, users[ticket["requester_id"]]) }
  end

  private

  def item(ticket, requester)
    { external_id: ticket["id"], body: [ ticket["subject"], ticket["description"] ].compact_blank.join("\n\n"),
      author: requester&.dig("name"), author_email: requester&.dig("email"), created_at: Time.zone.parse(ticket["created_at"].to_s) }
  end

  def users_by_id(ids)
    ids.each_slice(100).flat_map { |slice| Integration::Http.get("#{@base}/api/v2/users/show_many", headers: headers, params: { ids: slice.join(",") }).fetch("users", []) }
  end

  def headers
    @headers ||= Integration::Http.bearer(Integration::Http.post("#{@base}/oauth/tokens",
      { grant_type: "client_credentials", client_id: @client_id, client_secret: @client_secret, scope: "tickets:read users:read" }).fetch("access_token"))
  end
end
