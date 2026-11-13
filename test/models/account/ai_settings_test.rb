require "test_helper"

class Account::AiSettingsTest < ActiveSupport::TestCase
  setup { @account = accounts(:acme) }

  test "unset settings use the defaults" do
    assert_equal "oxybot-spark", @account.ai_model("assistant")
    assert_equal 5, @account.ai_setting("match_candidates")
  end

  test "form strings are cast and saved" do
    assert @account.update_ai_settings("match_candidates" => "3", "theme_distance" => "0.2", "weekly_report_enabled" => "0")

    assert_equal 3, @account.reload.ai_setting("match_candidates")
    assert_in_delta 0.2, @account.ai_setting("theme_distance")
    assert_equal false, @account.ai_setting("weekly_report_enabled")
  end

  test "values outside the safe range are refused" do
    assert_not @account.update_ai_settings("match_candidates" => "0")
    assert_not @account.update_ai_settings("agent_max_rounds" => "500")
  end

  test "the chosen model alias is the one sent to LiteLLM" do
    @account.update_ai_settings("model_extract" => "cheap-extractor")
    note = @account.feedback_notes.create!(source: "manual", body: "Please add PDF export of reports for finance.")

    note.extract_insights

    assert_equal 1, llm_requests("cheap-extractor").size
  end

  test "the weekly report is due once, in the account's day, hour and time zone" do
    @account.update!(time_zone: "Warsaw")
    @account.update_ai_settings("weekly_report_day" => "1", "weekly_report_hour" => "8")
    monday_8am_warsaw = Time.find_zone("Warsaw").local(2026, 11, 16, 8, 5)

    assert @account.opportunity_report_due?(monday_8am_warsaw)
    assert_not @account.opportunity_report_due?(monday_8am_warsaw + 1.hour)

    travel_to(monday_8am_warsaw) { @account.documents.create!(kind: "opportunity_report", title: "Week", status: "ready", body: "## Summary") }
    assert_not @account.opportunity_report_due?(monday_8am_warsaw), "already drafted this week"
  end

  test "the hourly job drafts reports only for accounts that are due" do
    @account.update_ai_settings("weekly_report_day" => Time.current.wday.to_s, "weekly_report_hour" => Time.current.hour.to_s)
    accounts(:globex).update_ai_settings("weekly_report_enabled" => "0")

    OpportunityDiscoveryJob.perform_now

    assert_equal 1, @account.documents.where(kind: "opportunity_report").count
    assert_equal 0, accounts(:globex).documents.count
  end
end
