# Stands in for HubSpot until a private app token is set: same return shape as Client, data from a YAML file.
class Integration::Hubspot::MockClient
  def initialize(path = Rails.root.join("config/mocks/hubspot.yml"))
    @data = YAML.load_file(path)
  end

  def companies(properties:)
    @data.fetch("companies").map { |company| { id: company["id"].to_s, properties: company.except("id").slice(*properties) } }
  end

  def contacts
    @data.fetch("contacts").map do |contact|
      { id: contact["id"].to_s, properties: contact.slice("email", "firstname", "lastname"), company_id: contact["company_id"]&.to_s }
    end
  end
end
