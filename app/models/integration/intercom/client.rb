# Intercom REST API 2.18 (https://developers.intercom.com/docs/references/rest-api/api.intercom.io/conversations/searchconversations).
# Search returns conversations without their parts, so each one is fetched as plain text; only messages written by
# the customer are kept (the opening message and contact comments), never notes, events or AI answers.
class Integration::Intercom::Client
  BASE = "https://api.intercom.io"
  VERSION = "2.18"
  MAX_CONVERSATIONS = 500 # per sync

  def initialize(token, tag: nil)
    @headers = Integration::Http.bearer(token).merge("Intercom-Version" => VERSION)
    @tag = tag.presence
  end

  def me = Integration::Http.get("#{BASE}/me", headers: @headers)

  def feedback_since(time)
    conversation_ids(time).filter_map { |id| item(Integration::Http.get("#{BASE}/conversations/#{id}", headers: @headers, params: { display_as: "plaintext" })) }
  end

  private

  def conversation_ids(time)
    filters = [ { field: "updated_at", operator: ">", value: time.to_i }, ({ field: "tag_ids", operator: "=", value: @tag } if @tag) ].compact
    ids = []
    after = nil
    loop do
      body = Integration::Http.post("#{BASE}/conversations/search", { query: { operator: "AND", value: filters },
                                                                      pagination: { per_page: 150, starting_after: after }.compact,
                                                                      sort: { field: "updated_at", order: "ascending" } }, headers: @headers)
      ids.concat(body.fetch("conversations", []).map { |conversation| conversation["id"] })
      after = body.dig("pages", "next", "starting_after")
      break if after.nil? || ids.size >= MAX_CONVERSATIONS
    end
    ids.first(MAX_CONVERSATIONS)
  end

  def item(conversation)
    source = conversation.fetch("source", {})
    author = source["author"] || {}
    contact_parts = conversation.dig("conversation_parts", "conversation_parts").to_a.select do |part|
      part["part_type"] == "comment" && %w[user lead contact].include?(part.dig("author", "type")) && !part.dig("author", "from_ai_agent")
    end
    texts = ([ (source["body"] if %w[user lead contact].include?(author["type"])) ] + contact_parts.map { |part| part["body"] }).compact_blank
    return if texts.empty?

    { external_id: conversation["id"], body: texts.join("\n\n"), author: author["name"], author_email: author["email"],
      created_at: Time.at(conversation["created_at"].to_i) }
  end
end
