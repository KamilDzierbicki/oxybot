require "test_helper"

class Integration::HubspotTest < ActiveSupport::TestCase
  test "mock sync creates customers with ARR and links contacts to them" do
    integrations(:acme_hubspot).sync

    fabrikam = accounts(:acme).customers.find_by!(hubspot_id: "9003")
    assert_equal 210_000_00, fabrikam.arr_cents
    assert_equal "fabrikam.example", fabrikam.domain
    assert_equal fabrikam, accounts(:acme).contacts.find_by!(email: "priya@fabrikam.example").customer
  end

  test "a customer added before the first sync is adopted by domain, not duplicated" do
    integrations(:acme_hubspot).sync

    northwind = customers(:northwind).reload
    assert_equal "9001", northwind.hubspot_id
    assert_equal 1, accounts(:acme).customers.where(domain: "northwind.example").count
  end

  test "syncing twice updates instead of duplicating" do
    2.times { integrations(:acme_hubspot).sync }

    assert_equal 1, accounts(:acme).customers.where(hubspot_id: "9001").count
  end

  test "the ARR property name is configurable per portal" do
    integration = integrations(:acme_hubspot)
    integration.update!(arr_property: "annual_recurring_revenue")
    stub_hubspot(companies: [ { id: "1", properties: { name: "Big Co", domain: "big.example", annual_recurring_revenue: "1500.50" } } ])
    integration.update!(access_token: "pat-test")

    integration.sync

    assert_equal 150_050, accounts(:acme).customers.find_by!(hubspot_id: "1").arr_cents
  end

  test "the real client follows HubSpot's pagination and reads contact associations" do
    stub_hubspot(
      companies: [ { id: "1", properties: { name: "A" } } ], companies_page2: [ { id: "2", properties: { name: "B" } } ],
      contacts: [ { id: "7", properties: { email: "x@a.example" }, associations: { companies: { results: [ { id: "1", type: "contact_to_company" } ] } } } ]
    )
    client = Integration::Hubspot::Client.new("pat-test")

    assert_equal %w[1 2], client.companies(properties: %w[name]).map { |company| company[:id] }
    assert_equal "1", client.contacts.first[:company_id]
  end

  private

  def stub_hubspot(companies:, contacts: [], companies_page2: nil)
    first_page = { results: companies, paging: (companies_page2 ? { next: { after: "cursor-2" } } : nil) }.compact
    stub_request(:get, %r{api.hubapi.com/crm/v3/objects/companies}).with { |request| !request.uri.query.include?("after=") }
                                                                     .to_return(body: first_page.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{api.hubapi.com/crm/v3/objects/companies.*after=cursor-2}).to_return(body: { results: companies_page2.to_a }.to_json)
    stub_request(:get, %r{api.hubapi.com/crm/v3/objects/contacts}).to_return(body: { results: contacts }.to_json)
  end
end
