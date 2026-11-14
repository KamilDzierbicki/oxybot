# Salesforce REST API v68.0: OAuth client credentials at the My Domain token endpoint, then SOQL queries paged
# through nextRecordsUrl (https://developer.salesforce.com/docs/platform/api-rest/guide/dome-query.html).
class Integration::Salesforce::Client
  VERSION = "v68.0"
  MAX_PAGES = 50

  def initialize(instance_url, client_id, client_secret)
    @login = instance_url.to_s.delete_suffix("/")
    @client_id = client_id
    @client_secret = client_secret
  end

  # Field names are checked against Integration::Salesforce::FIELD before they get here
  def accounts(arr_field:, plan_field:, limit: nil)
    fields = [ "Id", "Name", "Website", arr_field, plan_field.presence ].compact.uniq
    query("SELECT #{fields.join(", ")} FROM Account#{" LIMIT #{limit.to_i}" if limit}")
  end

  def contacts = query("SELECT Id, Name, Email, AccountId FROM Contact WHERE Email != null")

  private

  def query(soql)
    records = []
    body = Integration::Http.get("#{instance}/services/data/#{VERSION}/query/", headers: headers, params: { q: soql })
    MAX_PAGES.times do
      records.concat(body.fetch("records"))
      break if body["done"] || body["nextRecordsUrl"].blank?

      body = Integration::Http.get("#{instance}#{body["nextRecordsUrl"]}", headers: headers)
    end
    records
  end

  def instance = token.fetch("instance_url")
  def headers = Integration::Http.bearer(token.fetch("access_token"))

  def token
    @token ||= Integration::Http.post("#{@login}/services/oauth2/token",
                                      { grant_type: "client_credentials", client_id: @client_id, client_secret: @client_secret }, form: true)
  end
end
