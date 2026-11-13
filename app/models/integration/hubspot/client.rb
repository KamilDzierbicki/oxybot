# HubSpot CRM v3 over plain HTTPS with a private app token. Returns plain hashes:
# companies: { id:, properties: }, contacts: { id:, properties:, company_id: }.
class Integration::Hubspot::Client
  BASE_URL = "https://api.hubapi.com"
  PAGE_SIZE = 100

  class Error < StandardError; end

  def initialize(token)
    @token = token
  end

  def companies(properties:)
    each_page("/crm/v3/objects/companies", properties: properties.join(",")).map do |result|
      { id: result["id"], properties: result["properties"] }
    end
  end

  def contacts
    each_page("/crm/v3/objects/contacts", properties: "email,firstname,lastname", associations: "companies").map do |result|
      company_id = result.dig("associations", "companies", "results")&.first&.dig("id")
      { id: result["id"], properties: result["properties"], company_id: company_id }
    end
  end

  private

  def each_page(path, **params)
    results = []
    after = nil
    loop do
      body = get(path, params.merge(limit: PAGE_SIZE, after: after).compact)
      results.concat(body.fetch("results"))
      after = body.dig("paging", "next", "after")
      break if after.nil?
    end
    results
  end

  def get(path, params)
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get_response(uri, "Authorization" => "Bearer #{@token}")
    raise Error, "HubSpot #{path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
