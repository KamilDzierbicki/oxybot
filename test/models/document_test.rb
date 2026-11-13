require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup do
    embed_features
    @account = accounts(:acme)
    note = @account.feedback_notes.create!(source: "manual", body: "placeholder", customer: customers(:northwind))
    @evidence = note.insights.create!(account: @account, product: products(:reports), customer: customers(:northwind),
                                      quote: "We need PDF export of reports for the board", summary: "PDF export of reports for the board")
    @evidence.link_to(features(:pdf_export))
  end

  test "a spec is drafted from the template, cites the feature's evidence and uses the code" do
    spec = draft("prd", feature: features(:pdf_export))

    assert_equal "ready", spec.status
    assert_includes spec.body, "## Problem and evidence"
    assert_equal [ @evidence.id ], spec.cited_insight_ids
    assert_includes spec.body, "app/models/report.rb", "the GitHub mock repository mentions PDF export there"
    assert_equal 1, spec.versions.count
  end

  test "a person's edit is a new version, and citations of another tenant's insights do not count" do
    spec = draft("prd", feature: features(:pdf_export))
    foreign = accounts(:globex).feedback_notes.create!(source: "manual", body: "x").insights.create!(account: accounts(:globex), product: products(:billing), quote: "q", summary: "s")

    spec.edit("#{spec.body}\n\nAlso [insight:#{foreign.id}]", user: users(:kamil), summary: "Added a note")

    assert_equal 2, spec.versions.count
    assert_equal users(:kamil), spec.versions.last.user
    assert_not_includes spec.cited_insight_ids, foreign.id
  end

  test "a requested change waits for review and only lands on accept" do
    spec = draft("prd", feature: features(:pdf_export))
    original = spec.body

    suggestion = spec.request_change("Make it shorter", user: users(:kamil))
    perform_enqueued_jobs(only: ReviseDocumentJob)

    assert_equal "pending", suggestion.reload.status
    assert_equal original, spec.reload.body, "the agent never edits in place"
    assert suggestion.diff.removed_count.positive?
    assert_not_includes suggestion.body, "Request:", "the request is not part of the document"

    suggestion.accept(user: users(:kamil))
    assert_equal suggestion.body, spec.reload.body
    assert_equal "accepted", suggestion.reload.status
    assert_match "Accepted agent suggestion", spec.versions.last.summary
  end

  test "a suggestion made before someone else's edit is stale" do
    spec = draft("prd", feature: features(:pdf_export))
    suggestion = spec.request_change("Make it shorter", user: users(:kamil))
    perform_enqueued_jobs(only: ReviseDocumentJob)

    spec.edit("#{spec.body}\n\nManual line", user: users(:kamil), summary: "Manual edit")

    assert suggestion.reload.stale?
  end

  test "with auto-accept on, the agent's change is applied right away" do
    spec = draft("prd", feature: features(:pdf_export))
    spec.update!(auto_accept: true)

    spec.request_change("Make it shorter", user: users(:kamil))
    perform_enqueued_jobs(only: ReviseDocumentJob)

    assert_equal 2, spec.versions.count
  end

  test "release notes list the contacts of customers who asked for a released feature" do
    @evidence.update!(feature: nil)
    insight = @evidence.feedback_note.insights.create!(account: @account, product: products(:mobile), customer: customers(:northwind),
                                                       quote: "Shopify orders please", summary: "Import Shopify orders")
    insight.link_to(features(:shopify))

    notes = draft("release_notes")

    assert_includes notes.body, "anna@northwind.example"
    assert_includes notes.cited_insight_ids, insight.id
  end

  test "a launch review compares the spec's success metrics with usage and post-launch feedback" do
    spec = draft("prd", feature: features(:shopify))
    spec.edit("## Goals and success metrics\n- 20% of eligible accounts connect within 30 days\n", user: users(:kamil), summary: "metrics")

    review = draft("launch_review", feature: features(:shopify))

    assert_includes review.body, "14 of 120", "usage comes from the analytics mock"
  end

  test "the opportunity report is posted to the Slack report channel" do
    integrations(:acme_slack).update!(report_channel_id: "C_PRODUCT")

    report = draft("opportunity_report")

    post = integrations(:acme_slack).chat_messages.find_by!(channel_id: "C_PRODUCT")
    assert_includes post.text, report.title
    assert_includes post.text, "/documents/#{report.id}|Open in OxyBot>"
  end

  test "a revision that changes nothing is reported as failed, not offered for review" do
    spec = draft("prd", feature: features(:pdf_export))
    stub_request(:post, "http://mock-llm.test/v1/chat/completions").to_return do |request|
      body = JSON.parse(request.body)
      unchanged = body["messages"].last["content"].to_s[%r{<document>\n(.*)\n</document>}m, 1]
      { status: 200, headers: { "Content-Type" => "application/json" },
        body: { choices: [ { index: 0, finish_reason: "stop", message: { role: "assistant", content: { body: unchanged, rationale: "Shortened it." }.to_json } } ] }.to_json }
    end

    suggestion = spec.request_change("Make it shorter", user: users(:kamil))
    perform_enqueued_jobs(only: ReviseDocumentJob)

    assert_equal "failed", suggestion.reload.status
  end

  test "a failed model call marks the document failed instead of leaving it drafting" do
    stub_request(:post, "http://mock-llm.test/v1/chat/completions").to_return(status: 500, body: { error: { message: "down" } }.to_json)

    assert_equal "failed", draft("voc_report").status
  end

  private

  def draft(kind, feature: nil)
    document = Document.draft(account: @account, kind: kind, creator: users(:kamil), feature: feature)
    perform_enqueued_jobs(only: GenerateDocumentJob)
    document.reload
  end
end
