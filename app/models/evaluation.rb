# Measures OxyBot's AI steps on the datasets in config/evals with a chosen model, calling the same code as production:
#
# - extraction: FeedbackNote#ask_extractor finds the expected products in the expected number (correct)
# - matching: the production path, hybrid search for candidates then Insight#judge, picks the expected feature or
#   none (correct); candidates_hit says whether search offered the expected feature at all
# - retrieval: hybrid search on a fixed corpus, with MRR and recall@5 for vector, full-text and fused search
# - documents: a drafted document against a reference, with BLEU-4 and ROUGE-1/2/L
#
# Nothing is kept in the database: the model is switched on an unsaved copy of the account, and retrieval and
# documents run inside a transaction that is rolled back. With Langfuse configured the run is a Langfuse experiment:
# dataset items, one trace per item with input, output and expected output, and every score on its root.
# The datasets are demo data written for this, so their text may be sent to Langfuse; customer data never is.
#
# A run measures one variant: the model, the version of the task's prompt (a label or number, Prompt.using) and
# retrieval overrides. The variant is the experiment's metadata, so variants sit side by side in Langfuse.
class Evaluation
  TASKS = %w[extraction matching retrieval documents].freeze
  BOOLEAN_SCORES = %w[correct candidates_hit].freeze
  # The prompt each task runs; its config holds the retrieval parameters the task uses
  PROMPTS = { "extraction" => "insight-extractor", "matching" => "feature-judge", "retrieval" => "product-agent", "documents" => "document-writer" }.freeze
  SEARCH_MODES = %i[vector text hybrid].freeze

  # scores: name => value between 0 and 1; "correct" is 0 or 1
  Result = Data.define(:id, :correct, :expected, :actual, :scores) do
    def initialize(id:, correct:, expected:, actual:, scores: nil)
      super(id:, correct:, expected:, actual:, scores: scores || { "correct" => correct ? 1 : 0 })
    end
  end

  attr_reader :task, :model, :run_name, :variant

  # prompt: label or version of the task's prompt (default production); retrieval: overrides such as {"rrf_k" => 30}
  def initialize(task:, model:, account:, prompt: nil, retrieval: {})
    raise ArgumentError, "task must be one of #{TASKS.join(", ")}" unless TASKS.include?(task)

    @task = task
    @model = model
    @versions = prompt ? { PROMPTS.fetch(task) => prompt } : {}
    @retrieval = retrieval.to_h.stringify_keys
    @account = Account.find(account.id).tap do |copy|
      copy.ai_settings = copy.ai_settings.merge("model_extract" => model, "model_judge" => model, "model_writer" => model)
    end
    @variant = within_variant do
      { "model" => model, "prompt" => Prompt.version_tag(PROMPTS.fetch(task)), "retrieval" => Prompt.retrieval(PROMPTS.fetch(task)).presence }.compact
    end
    label = [ model, variant["prompt"], *@retrieval.map { |key, value| "#{key}=#{value}" } ].join(" ")
    @run_name = "#{task} #{label} #{Time.current.utc.strftime("%Y-%m-%d %H:%M:%S")}"
  end

  def items
    @items ||= case task
    when "retrieval" then dataset.fetch("queries")
    when "matching" then dataset + @account.evaluation_cases.approved.where(task: "matching").order(:id).map(&:to_item)
    else dataset
    end
  end

  def dataset
    @dataset ||= YAML.load_file(Rails.root.join("config/evals/#{task}.yml"))
  end

  def run
    dataset_id = sync_dataset if Langfuse.configured?
    within_variant do
      next items.map { |item| experiment_item(item, dataset_id) { evaluate(item) } } if %w[extraction matching].include?(task)

      results = nil
      ActiveRecord::Base.transaction do
        results = items.map { |item| experiment_item(item, dataset_id) { evaluate(item) } }
        raise ActiveRecord::Rollback # retrieval's corpus and documents' drafts are never kept
      end
      results
    end
  end

  def self.accuracy(results) = results.empty? ? 0.0 : results.count(&:correct).fdiv(results.size)

  # Average of each score over the results
  def self.averages(results)
    results.flat_map { |result| result.scores.keys }.uniq.to_h do |name|
      values = results.filter_map { |result| result.scores[name] }
      [ name, (values.sum.to_f / values.size).round(3) ]
    end
  end

  private

  def within_variant(&) = Prompt.using(@versions, retrieval: @retrieval, &)

  def evaluate(item) = send(:"evaluate_#{task}", item)

  # Right when the insights fall into exactly the expected products, in the expected number
  def evaluate_extraction(item)
    insights = @account.feedback_notes.new(source: "manual", body: item["input"]).ask_extractor
    products = insights.map { |insight| insight["product_slug"] }
    expected = item["expected"]
    correct = products.uniq.sort == expected["products"].sort && products.size.between?(expected["min"], expected["max"])
    Result.new(id: item["id"], correct: correct, expected: expected, actual: { "products" => products.sort })
  end

  # Right when the judge picks the expected feature among the candidates search offers, or none when none fits
  def evaluate_matching(item)
    product = @account.products.find_by!(slug: item["product"])
    insight = @account.insights.new(product: product, summary: item["input"], quote: item["input"])
    candidates = insight.match_candidates
    verdict = insight.judge(candidates)
    picked = candidates.find { |feature| feature.id == verdict["feature_id"] }
    expected = item.dig("expected", "feature")
    correct = picked&.title == expected
    hit = expected.nil? || candidates.any? { |feature| feature.title == expected }
    Result.new(id: item["id"], correct: correct, expected: item["expected"], actual: { "feature" => picked&.title, "candidates" => candidates.map(&:title) },
               scores: { "correct" => correct ? 1 : 0, "candidates_hit" => hit ? 1 : 0 })
  end

  # Ranks the corpus for the query in each search mode; the hybrid ranking is what the assistant gets
  def evaluate_retrieval(item)
    corpus = retrieval_corpus
    space, vectors = EmbeddingSpace.embed([ item["query"] ], task: :query)
    vector = vectors.first
    relevant = item["relevant"]
    rankings = SEARCH_MODES.to_h do |mode|
      ranking = corpus[:account].insights.ranked(item["query"], mode: mode, vector: vector, space: space, tuning: Prompt.retrieval("product-agent"))
      [ mode, ranking.map { |insight| corpus[:keys][insight.id] }.first(10) ]
    end
    scores = SEARCH_MODES.each_with_object({}) do |mode, all|
      all["mrr_#{mode}"] = RetrievalMetrics.reciprocal_rank(rankings[mode], relevant).round(4)
      all["recall_at_5_#{mode}"] = RetrievalMetrics.recall_at(5, rankings[mode], relevant).round(4)
    end
    Result.new(id: item["id"], correct: scores["recall_at_5_hybrid"] == 1.0, expected: { "relevant" => relevant },
               actual: { "hybrid_top_5" => rankings[:hybrid].first(5) }, scores: scores)
  end

  # Drafts the document with the production writer and compares it with the reference
  def evaluate_documents(item)
    feature = @account.features.find_by!(title: item["feature"]) if item["feature"]
    template = @account.document_templates.where(kind: item["kind"]).order(:id).first
    document = @account.documents.create!(kind: item["kind"], feature: feature, document_template: template, title: "Evaluation #{item["id"]}")
    Document::Generation.new(document).run
    scores = TextMetrics.scores(document.reload.body, item["reference"])
    Result.new(id: item["id"], correct: document.ready?, expected: { "reference" => item["reference"] },
               actual: { "body" => document.body.to_s.truncate(4_000) }, scores: scores)
  end

  # A scratch workspace with the corpus as insights, embedded once per run (rolled back with the run)
  def retrieval_corpus
    @retrieval_corpus ||= begin
      account = Account.create!(name: "Retrieval evaluation #{run_name}")
      note = account.feedback_notes.create!(source: "manual", body: "Retrieval evaluation corpus", processed_at: Time.current)
      products = dataset.fetch("corpus").map { |doc| doc["product"] }.uniq.to_h do |slug|
        [ slug, account.products.create!(name: slug.humanize, slug: slug, description: slug.humanize) ]
      end
      keys = {}
      insights = dataset.fetch("corpus").map do |doc|
        note.insights.create!(account: account, product: products.fetch(doc["product"]), summary: doc["text"], quote: doc["text"]).tap { |insight| keys[insight.id] = doc["key"] }
      end
      Insight.embed_all(insights)
      { account: account, keys: keys }
    end
  end

  def dataset_name = "oxybot-#{task}"
  def item_id(item) = "oxybot-#{task}-#{item["id"]}"

  # Creates the dataset on first use and keeps its items equal to config/evals (items are upserted by id)
  def sync_dataset
    dataset = begin
      Langfuse.get("/api/public/v2/datasets/#{dataset_name}")
    rescue Langfuse::Error
      Langfuse.post("/api/public/v2/datasets", { name: dataset_name, description: "OxyBot demo #{task} cases (config/evals/#{task}.yml)" })
    end
    items.each do |item|
      next if private_text?(item) # cases from real corrections hold customer text
      Langfuse.post("/api/public/dataset-items", { datasetName: dataset_name, id: item_id(item), input: item_input(item),
                                                   expectedOutput: expected_output(item) })
    end
    dataset.fetch("id")
  end

  # One trace per item, marked as part of this experiment (Langfuse's OpenTelemetry experiment attributes)
  def experiment_item(item, dataset_id)
    tracer = OpenTelemetry.tracer_provider.tracer("oxybot")
    run = { "langfuse.experiment.id" => run_name, "langfuse.experiment.name" => run_name, "langfuse.experiment.dataset.id" => dataset_id,
            "langfuse.environment" => Langfuse.environment }.compact
    variant.each { |key, value| run["langfuse.experiment.metadata.#{key}"] = value.is_a?(Hash) ? value.to_json : value }
    context = OpenTelemetry::Baggage.build { |baggage| run.each { |key, value| baggage.set_value(key, value.to_s) } }

    root = tracer.start_span("experiment-item", with_parent: context, attributes: {
      "langfuse.observation.input" => item_input(item).to_json,
      "langfuse.experiment.item.expected_output" => expected_output(item).to_json,
      "langfuse.experiment.description" => "#{task} with #{variant.values_at("model", "prompt").join(", ")} on config/evals/#{task}.yml"
    })
    root_id = root.context.hex_span_id
    item_context = OpenTelemetry::Baggage.build(context: context) do |baggage|
      baggage.set_value("langfuse.experiment.item.id", item_id(item))
      baggage.set_value("langfuse.experiment.item.root_observation_id", root_id)
    end
    root.set_attribute("langfuse.experiment.item.id", item_id(item))
    root.set_attribute("langfuse.experiment.item.root_observation_id", root_id)

    result = OpenTelemetry::Context.with_current(OpenTelemetry::Trace.context_with_span(root, parent_context: item_context)) { yield }
    root.set_attribute("langfuse.observation.output", result.actual.to_json)
    root.finish
    score(root, result) if Langfuse.configured? && root.context.valid?
    result
  rescue StandardError
    root&.finish
    raise
  end

  def item_input(item) = private_text?(item) ? { "case" => item["id"] } : item.except("id", "expected", "relevant", "reference", "private")

  def private_text?(item) = item["private"] && !Rails.configuration.x.trace_content
  def expected_output(item) = item["expected"] || item.slice("relevant", "reference")

  def score(root, result)
    result.scores.each do |name, value|
      Langfuse.post("/api/public/scores", { traceId: root.context.hex_trace_id, observationId: root.context.hex_span_id, name: name, value: value,
                                            dataType: BOOLEAN_SCORES.include?(name) ? "BOOLEAN" : "NUMERIC", environment: Langfuse.environment })
    end
  end
end
