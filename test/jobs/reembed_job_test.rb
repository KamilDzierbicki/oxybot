require "test_helper"

class ReembedJobTest < ActiveSupport::TestCase
  setup do
    @acme = accounts(:acme)
    note = @acme.feedback_notes.create!(source: "manual", body: "placeholder")
    @insights = 70.times.map do |n|
      note.insights.create!(account: @acme, product: products(:reports), quote: "Need export number #{n}", summary: "Export #{n}")
    end
    @other = accounts(:globex).feedback_notes.create!(source: "manual", body: "x")
                              .insights.create!(account: accounts(:globex), product: products(:billing), quote: "q", summary: "s")
    WebMock::RequestRegistry.instance.reset!
  end

  test "embeds a workspace in batches of one call each, not one call per record" do
    ReembedJob.perform_now(@acme)

    assert_equal 0, @acme.insights.stale_embeddings.count + @acme.features.stale_embeddings.count
    assert_operator @acme.features.count, :<=, 64, "the fixtures fit one batch of features"
    assert_equal 3, embedding_calls, "one call for the features and two for 70 insights, not one call per record"
  end

  test "a rerun continues where the last one stopped instead of starting over" do
    Insight.embed_all(@insights.first(64)) # what an interrupted run had already finished
    WebMock::RequestRegistry.instance.reset!

    ReembedJob.perform_now(@acme)

    sent = embedding_inputs.flatten.grep(/Need export number/)
    assert_equal 6, sent.size, "only the 6 insights the first run did not reach are embedded again"
  end

  test "works on one workspace only" do
    ReembedJob.perform_now(@acme)

    assert @other.reload.embedding.nil?, "another tenant's records are left to that tenant's own job"
  end

  test "the hourly sweep queues only workspaces with stale vectors" do
    ReembedJob.perform_now(@acme)

    assert_enqueued_jobs 1, only: ReembedJob do
      ReembedJob.sweep
    end
    assert_enqueued_with(job: ReembedJob, args: [ accounts(:globex) ])
  end

  private

  def embedding_calls
    WebMock::RequestRegistry.instance.requested_signatures.hash.select { |request, _| request.uri.path.end_with?("/embeddings") }.values.sum
  end

  def embedding_inputs
    WebMock::RequestRegistry.instance.requested_signatures.hash.flat_map do |request, times|
      request.uri.path.end_with?("/embeddings") ? [ JSON.parse(request.body)["input"] ] * times : []
    end
  end
end
