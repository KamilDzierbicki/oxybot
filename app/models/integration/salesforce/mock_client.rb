# Salesforce in test mode: the demo customers from config/mocks/hubspot.yml in Salesforce's shape
class Integration::Salesforce::MockClient
  def initialize(path = Rails.root.join("config/mocks/hubspot.yml"))
    @data = YAML.load_file(path)
  end

  def accounts(arr_field:, plan_field:, limit: nil)
    @data.fetch("companies").first(limit || 1_000).map do |company|
      { "Id" => "001MOCK#{company["id"]}", "Name" => company["name"], "Website" => company["domain"], arr_field => company["arr"],
        plan_field.presence => company["plan"] }.compact
    end
  end

  def contacts
    @data.fetch("contacts").map do |contact|
      { "Id" => "003MOCK#{contact["id"]}", "Name" => [ contact["firstname"], contact["lastname"] ].compact.join(" "), "Email" => contact["email"],
        "AccountId" => ("001MOCK#{contact["company_id"]}" if contact["company_id"]) }
    end
  end
end
