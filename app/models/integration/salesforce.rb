# Salesforce accounts and contacts as customers, like the HubSpot sync. A server-to-server External Client App with
# the client credentials flow: access_token is the consumer key, secret the consumer secret, instance_url the My
# Domain address. ARR and plan are custom fields; their API names are settings (AnnualRevenue by default).
class Integration::Salesforce < Integration
  FIELD = /\A[A-Za-z][A-Za-z0-9_]{0,79}\z/ # Salesforce API names; anything else would end up inside a SOQL query

  store_accessor :settings, :instance_url, :arr_field, :plan_field

  validates :arr_field, :plan_field, format: { with: FIELD, message: "must be a Salesforce API field name, like ARR__c" }, allow_blank: true
  validate :instance_url_allowed, if: -> { instance_url.present? }

  def self.external_id_label = "Org id"

  def self.form_fields
    [ [ :instance_url, "My Domain address, like https://acme.my.salesforce.com", :text ],
      [ :arr_field, "Account field with ARR (default AnnualRevenue)", :text ], [ :plan_field, "Account field with plan (optional)", :text ],
      [ :access_token, "Consumer key", :password ], [ :secret, "Consumer secret", :password ] ]
  end

  def arr_field = super.presence || "AnnualRevenue"

  def verify_connection
    count = client.accounts(arr_field: arr_field, plan_field: plan_field, limit: 1).size
    [ true, "Salesforce answered; the integration user can read accounts (#{count} on the first page)." ]
  end

  def sync
    transaction do
      customers = client.accounts(arr_field: arr_field, plan_field: plan_field).to_h { |record| [ record["Id"], sync_account(record) ] }
      client.contacts.each { |record| sync_contact(record, customers) }
      update!(synced_at: Time.current)
    end
  end

  private

  def client = mock? ? MockClient.new : Client.new(instance_url, access_token, secret)

  def sync_account(record)
    domain = record["Website"].to_s.strip.downcase.sub(%r{\Ahttps?://}, "").delete_prefix("www.").split("/").first.presence
    customer = account.customers.find_by(salesforce_id: record["Id"]) ||
               (domain && account.customers.find_by(domain: domain, salesforce_id: nil)) ||
               account.customers.new(salesforce_id: record["Id"])
    customer.update!(salesforce_id: record["Id"], name: record["Name"].presence || "Salesforce account #{record["Id"]}", domain: domain,
                     arr_cents: (record[arr_field].to_f * 100).round, plan: (record[plan_field] if plan_field.present?), synced_at: Time.current)
    customer
  end

  def sync_contact(record, customers)
    return if record["Email"].blank?

    contact = account.contacts.find_or_initialize_by(email: record["Email"].downcase)
    contact.update!(salesforce_id: record["Id"], name: record["Name"].presence || contact.name, customer: customers[record["AccountId"]] || contact.customer)
  end

  def instance_url_allowed
    errors.add(:instance_url, "must be your https My Domain address") unless instance_url.start_with?("https://") && Integration::OutboundUrl.allowed?(instance_url)
  end
end
