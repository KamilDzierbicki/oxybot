require "test_helper"

# Request and response shapes follow each service's current API docs (cited in the client classes).
class NewIntegrationsTest < ActiveSupport::TestCase
  setup { @account = accounts(:acme) }

  test "Amplitude asks for weekly unique users of the feature's event and the launch review compares before and after" do
    released = Date.new(2026, 10, 5)
    feature = features(:shopify).tap { |record| record.update!(analytics_key: "Shopify Connected", released_at: released) }
    Integration::Amplitude.create!(account: @account, external_id: "123", access_token: "api-key", secret: "secret-key", region: "eu")
    request = stub_request(:get, %r{analytics\.eu\.amplitude\.com/api/2/events/segmentation})
                .with(basic_auth: %w[api-key secret-key], query: hash_including(m: "uniques", i: "7", e: { event_type: "Shopify Connected" }.to_json))
                .to_return(body: { data: { series: [ [ 100, 100, 150, 200 ] ], xValues: %w[2026-09-28 2026-10-05 2026-10-12 2026-10-19] } }.to_json)

    usage = Feature::UsageMetrics.for(feature)

    assert_requested request
    assert_includes usage[:lines].join("\n"), "Weekly users before the release: 28 Sep 100 (average 100)"
    assert_includes usage[:lines].join("\n"), "Change in average weekly users: 50%", "100 before, 150 average after"
    assert_not_includes usage[:source], "sample", "real data is not labeled as sample numbers"
  end

  test "Pendo counts distinct identified visitors of the feature per week" do
    integration = Integration::Pendo.create!(account: @account, external_id: "acme", access_token: "key", host: "app.eu.pendo.io")
    request = stub_request(:post, "https://app.eu.pendo.io/api/v1/aggregation").with(headers: { "x-pendo-integration-key" => "key" }) { |req|
      pipeline = JSON.parse(req.body).dig("request", "pipeline")
      pipeline.first.dig("source", "featureEvents", "featureId") == "feat-1" && pipeline.any? { |step| step["identified"] == "visitorId" } &&
        pipeline.any? { |step| step.dig("group", "fields", "users", "count") == "visitorId" }
    }.to_return(body: { results: [ { week: Time.utc(2026, 10, 4).to_i * 1000, users: 42 } ] }.to_json)

    weeks = integration.send(:client).weekly_users("feat-1", from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31))

    assert_requested request
    assert_equal [ { week: Date.new(2026, 9, 28), users: 42 } ], weeks, "Pendo's Sunday week is reported by its Monday"
  end

  test "Intercom imports what the customer wrote, not notes or AI answers, once per conversation" do
    integration = Integration::Intercom.create!(account: @account, external_id: "ws", access_token: "token")
    stub_request(:post, "https://api.intercom.io/conversations/search").with(headers: { "Intercom-Version" => "2.18" })
      .to_return(body: { conversations: [ { id: "1295" } ], pages: {} }.to_json)
    stub_request(:get, "https://api.intercom.io/conversations/1295?display_as=plaintext").to_return(body: {
      id: "1295", created_at: 1_763_000_000,
      source: { body: "I wish export worked", author: { type: "user", name: "Joe", email: "joe@northwind.example" } },
      conversation_parts: { conversation_parts: [
        { part_type: "comment", body: "Also CSV please", author: { type: "user" } },
        { part_type: "note", body: "internal: churn risk", author: { type: "admin" } },
        { part_type: "comment", body: "Here is an AI answer", author: { type: "bot", from_ai_agent: true } }
      ] }
    }.to_json)

    assert_equal 1, integration.sync
    note = @account.feedback_notes.find_by!(source: "intercom", external_id: "1295")
    assert_equal "I wish export worked\n\nAlso CSV please", note.body
    assert_equal customers(:northwind), note.customer, "matched by the email domain"
    assert_equal 0, integration.sync, "syncing again imports nothing twice"
  end

  test "Zendesk signs in with an OAuth client, keeps only tagged tickets and finds the requester" do
    integration = Integration::Zendesk.create!(account: @account, external_id: "acme", access_token: "client-id", secret: "client-secret")
    token = stub_request(:post, "https://acme.zendesk.com/oauth/tokens")
              .with(body: hash_including(grant_type: "client_credentials", client_id: "client-id", client_secret: "client-secret"))
              .to_return(body: { access_token: "zd-token" }.to_json)
    stub_request(:get, %r{acme\.zendesk\.com/api/v2/incremental/tickets/cursor}).with(headers: { "Authorization" => "Bearer zd-token" })
      .to_return(body: { tickets: [ { id: 35_436, subject: "Export", description: "I wish export worked", requester_id: 7, tags: [ "feedback" ], created_at: "2026-11-02T10:00:00Z" },
                                     { id: 35_437, subject: "Login", description: "Password reset", requester_id: 7, tags: [ "bug" ], created_at: "2026-11-02T11:00:00Z" } ],
                         users: [ { id: 7, name: "Joe", email: "joe@contoso.example" } ], end_of_stream: true }.to_json)

    assert_equal 1, integration.sync

    assert_requested token
    note = @account.feedback_notes.find_by!(source: "zendesk", external_id: "35436")
    assert_equal [ "Export\n\nI wish export worked", customers(:contoso) ], [ note.body, note.customer ]
  end

  test "a Zendesk answer without a signed-in agent fails the connection check" do
    integration = Integration::Zendesk.create!(account: @account, external_id: "acme", access_token: "id", secret: "secret")
    stub_request(:post, "https://acme.zendesk.com/oauth/tokens").to_return(body: { access_token: "t" }.to_json)
    stub_request(:get, "https://acme.zendesk.com/api/v2/users/me").to_return(body: { user: { id: nil, role: "end-user" } }.to_json)

    ok, _message = integration.check_connection

    assert_not ok
  end

  test "Gong keeps only what external speakers said on each call" do
    integration = Integration::Gong.create!(account: @account, external_id: "acme", access_token: "key", secret: "secret", base_url: "https://us-1.api.gong.io")
    stub_request(:post, "https://us-1.api.gong.io/v2/calls/extensive").with(basic_auth: %w[key secret]).to_return(body: {
      calls: [ { metaData: { id: "778", started: "2026-11-01T10:00:00Z" },
                 parties: [ { speakerId: "s-ext", name: "Jane", emailAddress: "jane@fabrikam.example", affiliation: "External" },
                            { speakerId: "s-int", name: "Rep", emailAddress: "rep@acme.example", affiliation: "Internal" } ] } ],
      records: {}
    }.to_json)
    stub_request(:post, "https://us-1.api.gong.io/v2/calls/transcript").to_return(body: {
      callTranscripts: [ { callId: "778", transcript: [ { speakerId: "s-int", sentences: [ { text: "What would help?" } ] },
                                                         { speakerId: "s-ext", sentences: [ { text: "We need SSO before renewal." } ] } ] } ],
      records: {}
    }.to_json)

    assert_equal 1, integration.sync
    note = @account.feedback_notes.find_by!(source: "gong", external_id: "778")
    assert_equal "We need SSO before renewal.", note.body
  end

  test "Gong's 404 for an empty window is not an error" do
    integration = Integration::Gong.create!(account: @account, external_id: "acme", access_token: "key", secret: "secret", base_url: "https://us-1.api.gong.io")
    stub_request(:post, "https://us-1.api.gong.io/v2/calls/extensive").to_return(status: 404, body: "{}")

    assert_equal 0, integration.sync
  end

  test "Salesforce syncs accounts with ARR and contacts through client credentials and query paging" do
    integration = Integration::Salesforce.create!(account: @account, external_id: "00D1", access_token: "key", secret: "secret",
                                                  instance_url: "https://acme.my.salesforce.com", arr_field: "ARR__c")
    stub_request(:post, "https://acme.my.salesforce.com/services/oauth2/token")
      .with(body: { grant_type: "client_credentials", client_id: "key", client_secret: "secret" })
      .to_return(body: { access_token: "sf-token", instance_url: "https://acme.my.salesforce.com" }.to_json)
    stub_request(:get, "https://acme.my.salesforce.com/services/data/v68.0/query/").with(query: hash_including(q: /FROM Account/))
      .to_return(body: { done: false, nextRecordsUrl: "/services/data/v68.0/query/01g-2000",
                         records: [ { Id: "001A", Name: "Northwind Logistics", Website: "https://www.northwind.example/", ARR__c: 130_000 } ] }.to_json)
    stub_request(:get, "https://acme.my.salesforce.com/services/data/v68.0/query/01g-2000")
      .to_return(body: { done: true, records: [ { Id: "001B", Name: "New Co", Website: "newco.example", ARR__c: 5_000 } ] }.to_json)
    stub_request(:get, "https://acme.my.salesforce.com/services/data/v68.0/query/").with(query: hash_including(q: /FROM Contact/))
      .to_return(body: { done: true, records: [ { Id: "003A", Name: "Anna", Email: "Anna@Newco.example", AccountId: "001B" } ] }.to_json)

    integration.sync

    assert_equal [ "001A", 13_000_000 ], customers(:northwind).reload.slice(:salesforce_id, :arr_cents).values, "adopted by domain, not duplicated"
    newco = @account.customers.find_by!(salesforce_id: "001B")
    assert_equal newco, @account.contacts.find_by!(email: "anna@newco.example").customer
  end

  test "Salesforce field names that are not API names are refused before they reach a query" do
    integration = Integration::Salesforce.new(account: @account, external_id: "00D2", arr_field: "Id FROM User --")

    assert_not integration.valid?
    assert integration.errors.key?(:arr_field)
  end

  test "a Hex run of the launch analysis is linked from the review" do
    feature = features(:shopify).tap { |record| record.update!(released_at: Date.new(2026, 10, 5)) }
    Integration::Hex.create!(account: @account, external_id: "acme", access_token: "hxtw_x", project_id: "0a1b2c3d-1111")
    run = stub_request(:post, "https://app.hex.tech/api/v1/projects/0a1b2c3d-1111/runs")
            .with(body: { inputParams: { feature: "Shopify connector", released_on: "2026-10-05" } }.to_json)
            .to_return(status: 201, body: { runUrl: "https://app.hex.tech/app/run/42" }.to_json)

    usage = Feature::UsageMetrics.for(feature)

    assert_requested run
    assert_includes usage[:lines].join, "https://app.hex.tech/app/run/42"
  end

  test "test mode syncs sample feedback once and sample customers, with no outside call" do
    intercom = Integration::Intercom.create!(account: @account, external_id: "ws-mock")
    salesforce = Integration::Salesforce.create!(account: @account, external_id: "00D-mock")

    assert_equal 2, intercom.sync
    assert_equal 0, intercom.sync
    salesforce.sync
    assert @account.customers.exists?(salesforce_id: "001MOCK9003")
  end
end
