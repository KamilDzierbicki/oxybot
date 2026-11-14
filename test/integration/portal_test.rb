require "test_helper"

class PortalTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @account.update!(portal_enabled: true, portal_slug: "acme")
    @shown = features(:pdf_export).tap { |feature| feature.update!(on_portal: true, roadmap_lane: "now") }
    @hidden = features(:offline_mode).tap { |feature| feature.update!(roadmap_lane: "next") }
  end

  test "a closed portal does not exist" do
    @account.update!(portal_enabled: false)

    get portal_root_path(portal_slug: "acme")

    assert_response :not_found
  end

  test "the portal shows only features marked for it, and never revenue or evidence" do
    get portal_root_path(portal_slug: "acme")

    assert_response :success
    assert_includes response.body, @shown.title
    assert_not_includes response.body, @hidden.title
    assert_no_match(/\$\d|ARR|insight/i, css_select("main").text)
  end

  test "signing in takes the emailed link and a button press, and the link works once" do
    token = request_link("Anna@Northwind.example")

    get portal_sign_in_path(portal_slug: "acme", token: token)
    assert_response :success, "opening the link (as mail scanners do) does not sign in yet"
    assert_nil cookies["portal_visitor_#{@account.id}"].presence

    patch portal_sign_in_path(portal_slug: "acme", token: token)
    assert_redirected_to portal_root_path(portal_slug: "acme")

    patch portal_sign_in_path(portal_slug: "acme", token: token)
    assert_equal "This link has expired or was already used. Ask for a new one.", flash[:alert]
  end

  test "a link is bound to the portal it was sent for" do
    accounts(:globex).update!(portal_enabled: true, portal_slug: "globex")
    token = request_link("anna@northwind.example")

    patch portal_sign_in_path(portal_slug: "globex", token: token)

    assert_equal "This link has expired or was already used. Ask for a new one.", flash[:alert]
  end

  test "a vote is customer evidence: it raises the feature's reach and ARR, and removing it takes that back" do
    sign_in_portal("anna@northwind.example")
    before = demand(@shown)

    assert_difference -> { @account.insights.where(feature: @shown).count }, 1 do
      post portal_feature_vote_path(portal_slug: "acme", feature_id: @shown)
    end
    after = demand(@shown)
    assert_equal customers(:northwind).id, @account.insights.where(feature: @shown).last.customer_id, "matched by the email's domain"
    assert_equal [ 0, 0 ], [ before.customer_count, before.demand_arr_cents ], "no evidence before the vote"
    assert_equal [ 1, customers(:northwind).arr_cents ], [ after.customer_count, after.demand_arr_cents ]

    post portal_feature_vote_path(portal_slug: "acme", feature_id: @shown)
    assert_equal 1, PortalVote.where(feature: @shown).count, "one vote per person"

    delete portal_feature_vote_path(portal_slug: "acme", feature_id: @shown)
    assert_equal before.insight_count, demand(@shown).insight_count
  end

  test "only features on this portal can be voted for" do
    sign_in_portal("anna@northwind.example")

    post portal_feature_vote_path(portal_slug: "acme", feature_id: @hidden)
    assert_response :not_found

    post portal_feature_vote_path(portal_slug: "acme", feature_id: features(:invoice_pdf))
    assert_response :not_found
  end

  test "voting needs a signed-in visitor" do
    post portal_feature_vote_path(portal_slug: "acme", feature_id: @shown)

    assert_redirected_to new_portal_session_path(portal_slug: "acme")
    assert_equal 0, PortalVote.count
  end

  test "an idea becomes portal feedback with the visitor's company, and goes to extraction" do
    sign_in_portal("anna@northwind.example")

    assert_enqueued_with(job: ExtractInsightsJob) do
      post portal_ideas_path(portal_slug: "acme"), params: { feedback_note: { body: "Let us export charts to PowerPoint." } }
    end

    note = @account.feedback_notes.order(:id).last
    assert_equal [ "portal", "anna@northwind.example", customers(:northwind).id ], [ note.source, note.author_email, note.customer_id ]
  end

  test "deleting a vote's feedback, or the whole workspace, works with portal data in place" do
    sign_in_portal("anna@northwind.example")
    post portal_feature_vote_path(portal_slug: "acme", feature_id: @shown)

    PortalVote.last.feedback_note.destroy!
    assert_equal 0, PortalVote.count

    post portal_feature_vote_path(portal_slug: "acme", feature_id: @shown)
    assert_nothing_raised { @account.destroy! }
  end

  private

  def request_link(email)
    post portal_session_path(portal_slug: "acme"), params: { email: email }
    perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
    ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{/sign_in/([^\s]+)}, 1]
  end

  def sign_in_portal(email)
    patch portal_sign_in_path(portal_slug: "acme", token: request_link(email))
  end

  def demand(feature) = @account.features.with_demand.find(feature.id)
end
