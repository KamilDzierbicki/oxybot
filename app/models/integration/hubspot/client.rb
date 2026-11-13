# HubSpot CRM v3 over plain HTTPS with a private app token. Returns plain hashes:
# companies: { id:, properties: }, contacts: { id:, properties:, company_id: }.
class Integration::Hubspot::Client
  BASE_URL = "https://api.hubapi.com"
  PAGE_SIZE = 100
  MAX_PAGES = 200 # 20,000 records per sync; a runaway paging loop stops here

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

  def sample_company_count
    get("/crm/v3/objects/companies", limit: 1).fetch("results").size
  end

  private

  def each_page(path, **params)
    results = []
    after = nil
    MAX_PAGES.times do
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
    request = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{@token}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
    raise Error, "HubSpot #{path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
