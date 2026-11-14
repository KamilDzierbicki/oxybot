require "test_helper"

class EvaluationTest < ActiveSupport::TestCase
  include TracingTestHelper

  MATCHING_ITEM = { "id" => "board-pdf", "product" => "reports", "input" => "Export reports to PDF with the company logo",
                    "expected" => { "feature" => "PDF export of reports" } }.freeze

  test "the dataset files only name products and features that the demo data has" do
    seeds = Rails.root.join("db/seeds.rb").read
    %w[extraction matching].each do |task|
      YAML.load_file(Rails.root.join("config/evals/#{task}.yml")).each do |item|
        Array(item.dig("expected", "products")).push(item["product"]).compact.each { |slug| assert_includes seeds, %("#{slug}"), item["id"] }
        feature = item.dig("expected", "feature")
        assert_includes seeds, %("#{feature}"), item["id"] if feature
      end
    end
  end

  test "a run measures the model on the same code path as production and writes nothing" do
    evaluation = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@items, [ MATCHING_ITEM ])

    results = assert_no_difference -> { Insight.count + FeedbackNote.count + accounts(:acme).reload.ai_settings.size } do
      evaluation.run
    end

    assert_equal [ "board-pdf" ], results.map(&:id)
    assert results.first.correct, "the mock judge picks the feature sharing the most words"
  end

  test "the judge is asked once per item, whatever the number of candidates" do
    evaluation = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@items, [ { "id" => "dark", "product" => "reports", "input" => "Dark mode at night",
                                                  "expected" => { "feature" => nil } } ])
    assert_operator products(:reports).features.count, :>, 1

    assert evaluation.run.first.correct
    calls = WebMock::RequestRegistry.instance.requested_signatures.hash.select { |request, _| request.uri.path.end_with?("/chat/completions") }.values.sum
    assert_equal 1, calls
  end

  test "extraction is right only with the expected products in the expected number" do
    evaluation = Evaluation.new(task: "extraction", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@items, [ { "id" => "pdf", "input" => "We really need to export reports to PDF with our logo for the board.",
                                                  "expected" => { "products" => [ "reports" ], "min" => 1, "max" => 1 } } ])

    assert evaluation.run.first.correct
  end

  test "with Langfuse the run is an experiment: dataset synced, one trace per item, a correct score on its root" do
    start_tracing
    stub_request(:get, "http://langfuse.test/api/public/v2/datasets/oxybot-matching").to_return(status: 404, body: "{}")
    create = stub_request(:post, "http://langfuse.test/api/public/v2/datasets").to_return(body: { id: "ds-1" }.to_json)
    item = stub_request(:post, "http://langfuse.test/api/public/dataset-items").to_return(body: "{}")
    score = stub_request(:post, "http://langfuse.test/api/public/scores").to_return(body: "{}")
    stub_request(:get, %r{langfuse\.test/api/public/v2/prompts}).to_return(status: 404, body: "{}") # prompts fall back to files

    evaluation = Evaluation.new(task: "matching", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@items, [ MATCHING_ITEM ])
    with_langfuse { evaluation.run }

    assert_requested create
    assert_requested item
    root = finished_spans.find { |span| span.name == "experiment-item" }
    assert_equal "ds-1", root.attributes["langfuse.experiment.dataset.id"]
    assert_equal root.hex_span_id, root.attributes["langfuse.experiment.item.root_observation_id"]
    assert_equal "oxybot-matching-board-pdf", root.attributes["langfuse.experiment.item.id"]

    model_call = finished_spans.find { |span| span.hex_trace_id == root.hex_trace_id && span.attributes["gen_ai.operation.name"] == "chat" }
    assert_equal evaluation.run_name, model_call.attributes["langfuse.experiment.id"], "the experiment context reaches every span of the item"

    assert_requested score
    sent = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.find { |request| request.uri.path.end_with?("/scores") }.body)
    assert_equal [ root.hex_trace_id, root.hex_span_id, "correct", 1 ], sent.values_at("traceId", "observationId", "name", "value")
  ensure
    stop_tracing
  end

  test "retrieval measures MRR and recall@5 for each search mode on its own corpus, and keeps nothing" do
    evaluation = Evaluation.new(task: "retrieval", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@dataset, {
      "corpus" => [ { "key" => "pdf", "product" => "reports", "text" => "Board meetings need reports exported to PDF." },
                    { "key" => "dark", "product" => "reports", "text" => "Dark mode for dashboards at night." },
                    { "key" => "shopify", "product" => "integrations", "text" => "The Shopify connector stops syncing." } ],
      "queries" => [ { "id" => "pdf-query", "query" => "reports exported to PDF", "relevant" => [ "pdf" ] } ]
    })

    results = assert_no_difference -> { [ Account.count, Insight.count, FeedbackNote.count ].sum } do
      evaluation.run
    end

    scores = results.first.scores
    assert_equal %w[mrr_hybrid mrr_text mrr_vector recall_at_5_hybrid recall_at_5_text recall_at_5_vector], scores.keys.sort
    assert_equal 1.0, scores["mrr_text"], "the only text match ranks first"
    assert_equal 1.0, scores["recall_at_5_hybrid"]
    assert results.first.correct
  end

  test "documents score a draft against the reference with BLEU and ROUGE, and keep nothing" do
    evaluation = Evaluation.new(task: "documents", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@dataset, [ { "id" => "notes", "kind" => "release_notes", "feature" => "Shopify connector",
                                                    "reference" => "## Highlights\n- Shopify connector: import orders and products." } ])

    results = assert_no_difference -> { Document.count } do
      evaluation.run
    end

    assert_equal %w[bleu rouge1 rouge2 rougeL], results.first.scores.keys.sort
    assert results.first.scores.except("correct").values.all? { |value| value.between?(0, 1) }
    assert_operator results.first.scores["rouge1"], :>, 0, "the mock draft shares words with the reference"
  end

  test "numeric scores reach Langfuse as numbers on the item's root" do
    start_tracing
    stub_request(:get, %r{langfuse\.test/api/public/v2/datasets/oxybot-retrieval}).to_return(body: { id: "ds-r" }.to_json)
    stub_request(:post, "http://langfuse.test/api/public/dataset-items").to_return(body: "{}")
    scores = stub_request(:post, "http://langfuse.test/api/public/scores").to_return(body: "{}")
    evaluation = Evaluation.new(task: "retrieval", model: "oxybot-haiku", account: accounts(:acme))
    evaluation.instance_variable_set(:@dataset, { "corpus" => [ { "key" => "pdf", "product" => "reports", "text" => "PDF export please" } ],
                                                  "queries" => [ { "id" => "q", "query" => "PDF export", "relevant" => [ "pdf" ] } ] })

    with_langfuse { evaluation.run }

    assert_requested scores, times: 6
    sent = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.select { |request| request.uri.path.end_with?("/scores") }.map { |request| JSON.parse(request.body) }
    assert_equal [ "NUMERIC" ], sent.map { |score| score["dataType"] }.uniq
  ensure
    stop_tracing
  end
end
