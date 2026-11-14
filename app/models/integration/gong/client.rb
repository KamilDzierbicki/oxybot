# Gong API v2 (https://help.gong.io/apidocs/introduction-2), basic auth with the access key and secret.
# Calls in the window come from /v2/calls/extensive with parties (to know who is External, the customer) and
# /v2/calls/transcript; a note holds the customer side of one call.
class Integration::Gong::Client
  MAX_PAGES = 20
  MAX_CHARS = 8_000

  def initialize(base_url, key, secret)
    @base = base_url.to_s.delete_suffix("/")
    @headers = Integration::Http.basic(key, secret)
  end

  # A 404 means "no calls in this window", which still proves the credentials work
  def ping
    Integration::Http.get("#{@base}/v2/calls", headers: @headers, params: { fromDateTime: 1.minute.ago.iso8601, toDateTime: Time.current.iso8601 })
  rescue Integration::Http::Error => e
    raise unless e.status == 404
  end

  def feedback_since(time)
    window = { fromDateTime: time.utc.iso8601, toDateTime: Time.current.utc.iso8601 }
    calls = each_page("/v2/calls/extensive", { filter: window, contentSelector: { context: "Extended", exposedFields: { parties: true } } }, "calls")
    return [] if calls.empty?

    transcripts = each_page("/v2/calls/transcript", { filter: window.merge(callIds: calls.map { |call| call.dig("metaData", "id") }) }, "callTranscripts")
                    .index_by { |transcript| transcript["callId"] }
    calls.filter_map { |call| item(call, transcripts[call.dig("metaData", "id")]) }
  end

  private

  def item(call, transcript)
    customers = call["parties"].to_a.select { |party| party["affiliation"] == "External" }
    speaker_ids = customers.map { |party| party["speakerId"] }.compact
    said = transcript.to_h.fetch("transcript", []).select { |turn| speaker_ids.include?(turn["speakerId"]) }
                     .flat_map { |turn| turn["sentences"].to_a.map { |sentence| sentence["text"] } }
    return if said.empty?

    { external_id: call.dig("metaData", "id"), body: said.join(" ").truncate(MAX_CHARS), author: customers.first&.dig("name"),
      author_email: customers.filter_map { |party| party["emailAddress"] }.first, created_at: Time.zone.parse(call.dig("metaData", "started").to_s) }
  end

  def each_page(path, body, key)
    results = []
    cursor = nil
    MAX_PAGES.times do
      page = Integration::Http.post("#{@base}#{path}", body.merge(cursor: cursor).compact, headers: @headers)
      results.concat(page.fetch(key, []))
      cursor = page.dig("records", "cursor")
      break if cursor.blank?
    end
    results
  rescue Integration::Http::Error => e
    e.status == 404 ? results : raise
  end
end
