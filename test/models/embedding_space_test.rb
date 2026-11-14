require "test_helper"

class EmbeddingSpaceTest < ActiveSupport::TestCase
  setup do
    @acme = accounts(:acme)
    note = @acme.feedback_notes.create!(source: "manual", body: "placeholder")
    @insights = 3.times.map do |n|
      note.insights.create!(account: @acme, product: products(:reports), quote: "PDF export of reports #{n}", summary: "PDF export #{n}")
    end
    Insight.embed_all(@insights)
    @first_space = EmbeddingSpace.active
  end

  test "every vector records the model that made it" do
    assert_equal [ @first_space.id ], @insights.map { |insight| insight.reload.embedding_space_id }.uniq
    assert_equal "oxybot-embed", @first_space.model_alias
  end

  test "another model behind the same alias, with the same dimensions, is noticed and its vectors are never mixed" do
    use_another_embedding_model

    assert_enqueued_with(job: ReembedJob, args: [ @acme ]) do
      @insights.first.embed
    end

    assert_not_equal @first_space, EmbeddingSpace.active, "a new model must get its own space"
    assert_equal @insights[1..].map(&:id), @acme.insights.stale_embeddings.where(id: @insights.map(&:id)).order(:id).pluck(:id),
                 "vectors of the old model are stale"

    results = @acme.insights.hybrid_search("zzzz qqqq") # no text match: only vectors could find something
    assert_equal [], results.map(&:id) - [ @insights.first.id ], "search must not compare old vectors with a query from the new model"
  end

  test "switching the alias back to an earlier model reuses its space, so its vectors are valid again" do
    use_another_embedding_model
    @insights.first.embed
    use_first_embedding_model

    assert_no_difference -> { EmbeddingSpace.count } do
      @insights.last.embed
    end

    assert_equal @first_space, EmbeddingSpace.active
    assert_equal [ @insights.first.id ], @acme.insights.stale_embeddings.where(id: @insights.map(&:id)).pluck(:id)
  end

  test "a model with other dimensions is refused before anything is stored" do
    error = assert_raises(ArgumentError) { EmbeddingSpace.identify([ 0.1 ] * 1024) }
    assert_match "1024 dimensions", error.message
  end

  private

  def use_another_embedding_model
    stub_request(:post, %r{mock-llm\.test/.*/embeddings}).to_rack(MockLlm.new(model_variant: 1))
  end

  def use_first_embedding_model
    stub_request(:post, %r{mock-llm\.test/.*/embeddings}).to_rack(MockLlm.new)
  end
end
