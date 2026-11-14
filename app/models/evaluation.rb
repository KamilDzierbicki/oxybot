# Runs the extractor or the feature judge over the demo dataset in config/evals with a chosen model and counts how
# often it gives the expected answer. It calls the same code as production (FeedbackNote#ask_extractor,
# Insight#judge) and writes nothing to the database: the model is switched on an unsaved copy of the account.
#
# With Langfuse configured, the run is also a Langfuse experiment: the dataset and its items are created or updated,
# every item gets its own trace with input, output and expected output, and a "correct" score. The dataset is demo
# data written for this purpose, so its text may be sent to Langfuse; customer data never is.
class Evaluation
  TASKS = %w[extraction matching].freeze

  Result = Data.define(:id, :correct, :expected, :actual)

  attr_reader :task, :model, :run_name

  def initialize(task:, model:, account:)
    raise ArgumentError, "task must be one of #{TASKS.join(", ")}" unless TASKS.include?(task)

    @task = task
    @model = model
    @account = Account.find(account.id).tap { |copy| copy.ai_settings = copy.ai_settings.merge("model_extract" => model, "model_judge" => model) }
    @run_name = "#{task} #{model} #{Time.current.utc.strftime("%Y-%m-%d %H:%M:%S")}"
  end

  def items
    @items ||= YAML.load_file(Rails.root.join("config/evals/#{task}.yml"))
  end

  def run
    dataset_id = sync_dataset if Langfuse.configured?
    items.map { |item| experiment_item(item, dataset_id) { evaluate(item) } }
  end

  def self.accuracy(results) = results.empty? ? 0.0 : results.count(&:correct).fdiv(results.size)

  private

  def evaluate(item)
    task == "extraction" ? evaluate_extraction(item) : evaluate_matching(item)
  end

  # Right when the insights fall into exactly the expected products, in the expected number
  def evaluate_extraction(item)
    insights = @account.feedback_notes.new(source: "manual", body: item["input"]).ask_extractor
    products = insights.map { |insight| insight["product_slug"] }
    expected = item["expected"]
    correct = products.uniq.sort == expected["products"].sort && products.size.between?(expected["min"], expected["max"])
    Result.new(id: item["id"], correct: correct, expected: expected, actual: { "products" => products.sort })
  end

  # Right when the judge picks the expected feature among all of the product's features, or none when none fits
  def evaluate_matching(item)
    product = @account.products.find_by!(slug: item["product"])
    candidates = product.features.order(:id).to_a
    insight = @account.insights.new(product: product, summary: item["input"], quote: item["input"])
    verdict = insight.judge(candidates)
    picked = candidates.find { |feature| feature.id == verdict["feature_id"] }
    Result.new(id: item["id"], correct: picked&.title == item.dig("expected", "feature"), expected: item["expected"],
               actual: { "feature" => picked&.title })
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
      Langfuse.post("/api/public/dataset-items", { datasetName: dataset_name, id: item_id(item), input: item.except("id", "expected"),
                                                   expectedOutput: item["expected"] })
    end
    dataset.fetch("id")
  end

  # One trace per item, marked as part of this experiment (Langfuse's OpenTelemetry experiment attributes)
  def experiment_item(item, dataset_id)
    tracer = OpenTelemetry.tracer_provider.tracer("oxybot")
    run = { "langfuse.experiment.id" => run_name, "langfuse.experiment.name" => run_name,
            "langfuse.experiment.dataset.id" => dataset_id, "langfuse.experiment.metadata.model" => model,
            "langfuse.environment" => Langfuse.environment }.compact
    context = OpenTelemetry::Baggage.build { |baggage| run.each { |key, value| baggage.set_value(key, value.to_s) } }

    root = tracer.start_span("experiment-item", with_parent: context, attributes: {
      "langfuse.observation.input" => item.except("id", "expected").to_json,
      "langfuse.experiment.item.expected_output" => item["expected"].to_json,
      "langfuse.experiment.description" => "#{task} with #{model} on config/evals/#{task}.yml"
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

  def score(root, result)
    Langfuse.post("/api/public/scores", { traceId: root.context.hex_trace_id, observationId: root.context.hex_span_id,
                                          name: "correct", value: result.correct ? 1 : 0, dataType: "BOOLEAN",
                                          environment: Langfuse.environment })
  end
end
