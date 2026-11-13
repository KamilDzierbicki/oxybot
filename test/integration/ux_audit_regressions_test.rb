require "test_helper"

# Behaviors added after the usability audit. Each test names the mistake it keeps from coming back.
class UxAuditRegressionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:kamil)
    @account = accounts(:acme)
    note = @account.feedback_notes.create!(source: "manual", body: "placeholder")
    @insight = note.insights.create!(account: @account, product: products(:reports), quote: "PDF export please",
                                     summary: "PDF export of reports", suggested_feature: features(:pdf_export))
  end

  test "a dismissed insight can be undone back into triage, and the undo is offered right away" do
    post insight_dismissal_path(@insight)
    assert @insight.reload.dismissed?
    follow_redirect!
    assert_select "#flash form[action=?]", insight_restoration_path(@insight)

    post insight_restoration_path(@insight)
    assert @insight.reload.pending?
    assert_nil @insight.feature
  end

  test "undo is scoped to the workspace" do
    other = accounts(:globex).feedback_notes.create!(source: "manual", body: "x")
                             .insights.create!(account: accounts(:globex), product: products(:billing), quote: "q", summary: "s")
    other.dismiss

    post insight_restoration_path(other)

    assert_response :not_found
    assert other.reload.dismissed?
  end

  test "an old document version can be restored, and the restore is itself a new version" do
    document = @account.documents.create!(kind: "prd", title: "Spec", status: "ready", body: "first")
    document.edit("first", user: users(:kamil), summary: "Draft")
    first = document.versions.last
    document.edit("second", user: users(:kamil), summary: "Edit")

    post document_version_restoration_path(document, first)

    assert_equal "first", document.reload.body
    assert_equal 3, document.versions.count, "the replaced text stays in the history"
  end

  test "accepting a suggestion offers an undo that brings the previous text back" do
    document = @account.documents.create!(kind: "prd", title: "Spec", status: "ready", body: "before")
    document.edit("before", user: users(:kamil), summary: "Draft")
    suggestion = document.suggestions.create!(instruction: "x", user: users(:kamil), base_version: document.versions.last,
                                              status: "pending", body: "after", rationale: "r")

    post document_suggestion_acceptance_path(document, suggestion)
    assert_equal "after", document.reload.body
    follow_redirect!
    post css_select("#flash form").first["action"]

    assert_equal "before", document.reload.body
  end

  test "a misspelled model name is refused while LiteLLM can list its models" do
    stub_request(:get, "#{Rails.configuration.x.llm_url}/models")
      .to_return(body: { data: %w[oxybot-extract oxybot-judge oxybot-spark oxybot-writer].map { |id| { id: id } } }.to_json)

    patch ai_settings_path, params: { account: { model_extract: "haiku-typo-xyz" } }

    assert_response :unprocessable_entity
    assert_equal "oxybot-extract", @account.reload.ai_model("extract")
  end

  test "model names are not blocked when LiteLLM cannot be asked" do
    stub_request(:get, "#{Rails.configuration.x.llm_url}/models").to_timeout

    patch ai_settings_path, params: { account: { model_extract: "my-own-alias" } }

    assert_redirected_to ai_settings_path
    assert_equal "my-own-alias", @account.reload.ai_model("extract")
  end

  test "inviting the same address twice leaves one open invitation" do
    2.times { post invitations_path, params: { invitation: { email: "new@acme.test", role: "member" } } }

    assert_equal 1, @account.invitations.open.where(email: "new@acme.test").count
  end

  test "search finds this workspace's records and never another's" do
    accounts(:globex).feedback_notes.create!(source: "manual", body: "zebrafish export from another tenant")
    @account.feedback_notes.create!(source: "manual", body: "zebrafish export for the board")

    get search_path(q: "zebrafish")

    assert_select "a", text: /zebrafish export for the board/
    assert_select "a", text: /another tenant/, count: 0

    get search_path(q: features(:pdf_export).title)
    assert_response :success
    assert_select "a", text: features(:pdf_export).title
  end

  test "a product with a blank slug gets its slug from the name, as the form promises" do
    post products_path, params: { product: { name: "Mobile App", slug: "", description: "Phones" } }

    assert_equal "mobile-app", @account.products.find_by(name: "Mobile App").slug
  end
end
