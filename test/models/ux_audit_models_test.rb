require "test_helper"

class UxAuditModelsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "feedback that arrives before any product waits, then is split when the first product is added" do
    account = Account.create!(name: "Fresh")
    note = account.feedback_notes.create!(source: "manual", body: "We need PDF export")

    note.extract_insights
    assert_not note.reload.processed?, "without a product, extraction must not mark the note done with zero insights"
    assert note.awaiting_product?

    assert_enqueued_with(job: ExtractInsightsJob, args: [ note ]) do
      account.products.create!(name: "Reports", description: "Reporting")
    end
  end

  test "the diff shows changes with context and folds long unchanged runs" do
    before = (1..20).map { |n| "line #{n}" }.join("\n")
    after = before.sub("line 10", "line ten")

    hunks = Document::Diff.new(before, after).hunks(context: 2)

    assert_equal %i[gap same same removed added same same gap], hunks.map(&:change)
    assert_equal "7", hunks.first.text, "lines 1 to 7 are folded"
  end

  test "match reasons name features by title, not by the id the model saw" do
    reason = Insight.new.send(:readable_reason, "Candidate 26 provides PDF export", [ Feature.new(id: 26, title: "PDF export") ])

    assert_equal "“PDF export” provides PDF export", reason
  end
end
