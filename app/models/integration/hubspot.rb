# The account's HubSpot portal. A sync copies companies (with ARR) and contacts into customers and contacts,
# so demand can be summed in SQL. Which company property holds ARR differs per portal: settings["arr_property"].
class Integration::Hubspot < Integration
  store_accessor :settings, :arr_property, :plan_property

  def arr_property = super.presence || "arr"
  def plan_property = super.presence || "plan"

  def sync_later
    SyncHubspotJob.perform_later(self)
  end

  def sync
    transaction do
      companies = client.companies(properties: [ "name", "domain", arr_property, plan_property ]).to_h do |company|
        [ company[:id], sync_company(company) ]
      end
      client.contacts.each { |contact| sync_contact(contact, companies) }
      update!(synced_at: Time.current)
    end
  end

  private

  def client
    mock? ? Integration::Hubspot::MockClient.new : Integration::Hubspot::Client.new(access_token)
  end

  def sync_company(company)
    properties = company[:properties]
    # A customer added before the first sync (same domain, no HubSpot id yet) is adopted, not duplicated
    domain = properties["domain"].to_s.strip.downcase.delete_prefix("www.").presence
    customer = account.customers.find_by(hubspot_id: company[:id]) ||
               (domain && account.customers.find_by(domain: domain, hubspot_id: nil)) ||
               account.customers.new(hubspot_id: company[:id])
    customer.hubspot_id = company[:id]
    customer.update!(name: properties["name"].presence || "HubSpot company #{company[:id]}", domain: properties["domain"],
                     arr_cents: (properties[arr_property].to_f * 100).round, plan: properties[plan_property], synced_at: Time.current)
    customer
  end

  def sync_contact(contact, companies)
    email = contact[:properties]["email"]
    return if email.blank?

    record = account.contacts.find_or_initialize_by(email: email.downcase)
    name = [ contact[:properties]["firstname"], contact[:properties]["lastname"] ].compact_blank.join(" ")
    record.update!(hubspot_id: contact[:id], name: name.presence, customer: companies[contact[:company_id]] || record.customer)
  end
end
