# Demo data: one tenant with products, a backlog, company knowledge, mock Slack and HubSpot, and raw feedback.
# Feedback notes enqueue extraction and matching jobs, which run once the app is up (bin/dev).
#
# Sign in as demo@openspark.local with the password "openspark-demo" (local demo account only).

account = Account.find_or_create_by!(name: "Acme Analytics")

account.users.find_or_create_by!(email_address: "demo@openspark.local") do |user|
  user.name = "Demo PM"
  user.password = "openspark-demo"
  user.slack_user_id = "U_DEMO"
end

products = {
  "reports" => [ "Reports", "Dashboards and reports: charts, filters, export to PDF and CSV, scheduled email reports, sharing with colleagues." ],
  "mobile" => [ "Mobile app", "iOS and Android app to view dashboards on the phone, with push notifications, offline mode and alerts." ],
  "integrations" => [ "Integrations", "Connectors that import data from Salesforce, HubSpot, Shopify and Google Sheets, plus the public API and webhooks." ]
}.to_h do |slug, (name, description)|
  [ slug, account.products.find_or_create_by!(slug: slug) { |product| product.name = name; product.description = description } ]
end

[
  [ "reports", "PDF export of reports", "Export any report or dashboard to a PDF file, with the company logo.", "planned" ],
  [ "reports", "Scheduled email reports", "Send a chosen report by email every day, week or month.", "idea" ],
  [ "reports", "Custom date ranges in charts", "Compare any two date ranges in a chart, like this quarter against the same quarter last year.", "idea" ],
  [ "mobile", "Offline mode", "Open the latest dashboards on the phone without internet connection.", "idea" ],
  [ "mobile", "Push alerts on metric thresholds", "Send a push notification when a metric crosses a threshold.", "in_progress" ],
  [ "integrations", "Salesforce two-way sync", "Write scores back to Salesforce opportunities, not only read them.", "idea" ],
  [ "integrations", "Shopify connector", "Import orders and products from Shopify stores.", "released" ],
  [ "integrations", "Webhook on report refresh", "Call a webhook when a report finishes refreshing.", "idea" ]
].each do |slug, title, description, status|
  account.features.find_or_create_by!(title: title) do |feature|
    feature.product = products.fetch(slug)
    feature.description = description
    feature.status = status
  end
end

account.knowledge_documents.find_or_create_by!(title: "Strategy 2027") do |document|
  document.body = <<~MARKDOWN
    Our goal for 2027 is to win mid-market logistics and retail companies (200 to 2,000 employees).
    Enterprise deals above $100k ARR stall without PDF export and audit-ready reports.
    We do not build a BI query language; we compete on ready-made dashboards.
  MARKDOWN
end

account.knowledge_documents.find_or_create_by!(title: "Personas") do |document|
  document.body = <<~MARKDOWN
    - **Operations director**: reads dashboards on the phone, often between warehouses with poor signal.
    - **Finance lead**: needs exports for the board and auditors, every month.
    - **Data engineer**: connects sources and wants an API and webhooks.
  MARKDOWN
end

Integration::Slack.find_or_create_by!(account: account, external_id: "T_DEMO") do |slack|
  slack.feedback_channel_ids = [ "C_FEEDBACK" ]
  slack.app_user_id = "U_OPENSPARK"
end

hubspot = Integration::Hubspot.find_or_create_by!(account: account, external_id: "424242") do |integration|
  integration.arr_property = "arr"
  integration.plan_property = "plan"
end
hubspot.sync # mock mode: reads config/mocks/hubspot.yml, no HTTP

[
  [ "anna@northwind.example", "Anna Kowalska", <<~TEXT ],
    Hi! Our board meets monthly and we still screenshot dashboards. We really need to export reports to PDF with our logo.
    Also the mobile app is useless in the warehouse: it cannot open dashboards offline when the signal drops.
  TEXT
  [ "priya@fabrikam.example", "Priya Shah", <<~TEXT ],
    Auditors asked for monthly reports as PDF files. Without PDF export we cannot roll Acme out to the other hospitals.
  TEXT
  [ "mark@contoso.example", "Mark Lee", <<~TEXT ],
    Could you send the sales dashboard by email every Monday morning? Our store managers never log in.
    It would also help to compare this quarter with the same quarter last year in the charts.
  TEXT
  [ "ola@litware.example", "Ola Nowak", <<~TEXT ],
    We need the scores written back to Salesforce opportunities. Reading only is not enough for our sales team.
  TEXT
  [ "tom@tailspin.example", "Tom Berg", <<~TEXT ]
    Thanks for the great support last week! One thing: dark mode for the dashboards would be easier on the eyes at night.
  TEXT
].each do |email, author, body|
  account.feedback_notes.find_or_create_by!(source: "manual", body: body) do |note|
    note.author = author
    note.author_email = email
  end
end

puts "Seeded #{account.name}: #{account.products.count} products, #{account.features.count} features, " \
     "#{account.customers.count} customers, #{account.feedback_notes.count} feedback notes."
