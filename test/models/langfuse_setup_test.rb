require "test_helper"

class LangfuseSetupTest < ActiveSupport::TestCase
  include TracingTestHelper

  setup { start_tracing }
  teardown do
    stop_tracing
    Rails.configuration.x.trace_content = false
  end

  test "an answer's question, text and cited quotes reach the trace only when content tracing is switched on" do
    ask = lambda do
      conversation = users(:kamil).conversations.create!(account: accounts(:acme))
      conversation.ask("What do customers say about PDF export?")
      perform_enqueued_jobs(only: GenerateReplyJob)
      finished_spans.reverse.find { |span| span.name == "assistant-turn" }
    end

    off = ask.call
    assert_nil off.attributes["langfuse.observation.input"], "by default no customer text leaves OxyBot"

    Rails.configuration.x.trace_content = true
    on = ask.call
    assert_equal "What do customers say about PDF export?", JSON.parse(on.attributes["langfuse.observation.input"])
    assert on.attributes["langfuse.observation.output"].present?
    assert on.attributes.key?("langfuse.observation.metadata.evidence")
    assert_equal "assistant-turn", on.attributes["langfuse.trace.name"], "evaluation rules select traces by this name"
  end

  test "setup connects Langfuse to LiteLLM and creates evaluators and rules once" do
    stub_request(:get, /mock-llm\.test\/v1\/models/).to_return(body: { data: [ { id: "oxybot-judge" } ] }.to_json)
    connection = stub_request(:put, "http://langfuse.test/api/public/llm-connections").to_return(body: "{}")
    stub_request(:get, /langfuse\.test\/api\/public\/v2\/evaluators/).to_return(body: { data: [] }.to_json)
      .then.to_return(body: { data: [] }.to_json)
      .then.to_return(body: { data: [ { id: "e1", name: "oxybot-answer-grounded", prompt: [ { role: "user", content: "an older prompt" } ] },
                                      { id: "e2", name: "oxybot-extraction-faithful",
                                        prompt: [ { role: "user", content: Langfuse::Setup::EVALUATORS.last[:prompt] } ] } ] }.to_json)
    create_evaluator = stub_request(:post, "http://langfuse.test/api/public/v2/evaluators").to_return(body: { id: "e1" }.to_json)
    stub_request(:get, "http://langfuse.test/api/public/v2/evaluation-rules").to_return(body: { data: [] }.to_json)
      .then.to_return(body: { data: [] }.to_json)
      .then.to_return(body: { data: [ { id: "r1", name: "oxybot-answer-grounded" }, { id: "r2", name: "oxybot-extraction-faithful" } ] }.to_json)
    create_rule = stub_request(:post, "http://langfuse.test/api/public/v2/evaluation-rules").to_return(body: "{}")
    update_rule = stub_request(:patch, /langfuse\.test\/api\/public\/v2\/evaluation-rules\/r\d/).to_return(body: "{}")
    new_version = stub_request(:patch, "http://langfuse.test/api/public/v2/evaluators/e1").to_return(body: "{}")
    unchanged = stub_request(:patch, "http://langfuse.test/api/public/v2/evaluators/e2").to_return(body: "{}")
    stub_review_setup

    with_langfuse { 2.times { Langfuse::Setup.run(log: StringIO.new) } }

    assert_requested connection, times: 2
    sent = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.find { |request| request.method == :put }.body)
    assert_equal [ "oxybot-litellm", "openai", "http://litellm:4000/v1", false ], sent.values_at("provider", "adapter", "baseURL", "withDefaultModels")
    assert_requested create_evaluator, times: 2
    assert_requested create_rule, times: 2
    assert_requested update_rule, times: 2 # the second run updates the rules instead of adding new ones
    assert_requested new_version, times: 1 # a prompt changed in code becomes a new evaluator version
    assert_not_requested unchanged

    rule = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.find { |request| request.method == :post && request.uri.path.end_with?("evaluation-rules") }.body)
    assert_equal false, rule["enabled"], "without content in traces an evaluator would judge empty text, so its rule stays off"
    assert_equal [ "traceName", "isRootObservation" ], rule["filter"].map { |filter| filter["column"] }
  end

  test "setup creates the weekly review's failure_type config, its queue and the corrections dashboard once" do
    stub_evaluators_in_place
    stubs = stub_review_setup

    with_langfuse { 2.times { Langfuse::Setup.run(log: StringIO.new) } }

    assert_requested stubs[:create_config], times: 1
    config = JSON.parse(stubs[:bodies][:config].first)
    assert_equal [ "failure_type", "CATEGORICAL" ], config.values_at("name", "dataType")
    assert_equal %w[wrong_feature missed_need invented_fact wrong_product unclear ok], config["categories"].map { |category| category["label"] }
    assert_requested stubs[:create_queue], times: 1
    assert_equal [ "c1" ], JSON.parse(stubs[:bodies][:queue].first)["scoreConfigIds"], "reviewers score queue items with failure_type"

    assert_requested stubs[:create_widget], times: 8 # two tables and a line per decision and split, created once
    assert_requested stubs[:create_dashboard], times: 1
    layout = stubs[:bodies][:layout].last.then { |body| JSON.parse(body).dig("definition", "widgets") }
    assert_equal 8, layout.map { |tile| tile["widgetId"] }.uniq.size, "a rerun replaces the layout instead of adding tiles twice"
    widgets = stubs[:bodies][:widgets].map { |body| JSON.parse(body) }
    assert_equal %w[feature_match insight_kept suggestion_accepted], widgets.flat_map { |widget| widget["filters"].flat_map { |filter| Array(filter["value"]) } }.uniq.sort
    assert_equal %w[name observationModelName observationPromptVersion],
                 widgets.flat_map { |widget| widget["dimensions"].map { |dimension| dimension["field"] } }.uniq.sort,
                 "corrections split by the prompt version and model of the scored model call"
  end

  test "a model call names the Langfuse prompt version it was built from" do
    stub_request(:get, /langfuse\.test\/api\/public\/v2\/prompts\/feature-judge/)
      .to_return(body: { type: "text", prompt: Prompt.from_file("feature-judge").text, version: 4 }.to_json)
    Rails.cache.clear
    insight = accounts(:acme).insights.new(product: products(:reports), summary: "PDF export", quote: "PDF export please")

    with_langfuse { insight.judge(products(:reports).features.to_a) }

    model_call = finished_spans.find { |span| span.attributes["gen_ai.operation.name"] == "chat" }
    assert_equal [ "feature-judge", 4 ], model_call.attributes.values_at("langfuse.observation.prompt.name", "langfuse.observation.prompt.version")
  end

  private

  def stub_evaluators_in_place
    stub_request(:get, /mock-llm\.test\/v1\/models/).to_return(body: { data: [ { id: "oxybot-judge" } ] }.to_json)
    stub_request(:put, "http://langfuse.test/api/public/llm-connections").to_return(body: "{}")
    evaluators = Langfuse::Setup::EVALUATORS.each_with_index.map { |definition, index| { id: "e#{index}", name: definition[:name], prompt: [ { content: definition[:prompt] } ] } }
    stub_request(:get, /langfuse\.test\/api\/public\/v2\/evaluators/).to_return(body: { data: evaluators }.to_json)
    stub_request(:get, "http://langfuse.test/api/public/v2/evaluation-rules").to_return(body: { data: evaluators }.to_json)
    stub_request(:patch, /langfuse\.test\/api\/public\/v2\/evaluation-rules/).to_return(body: "{}")
  end

  # A stand-in Langfuse that remembers what was created, so a second run finds it by name like the real one
  def stub_review_setup
    bodies = Hash.new { |hash, key| hash[key] = [] }
    created = Hash.new { |hash, key| hash[key] = [] }
    creating = lambda do |kind|
      lambda do |request|
        bodies[kind] << request.body
        created[kind] << JSON.parse(request.body).merge("id" => "#{kind.to_s[0]}#{created[kind].size + 1}")
        { body: created[kind].last.to_json }
      end
    end
    listing = ->(kind) { ->(_request) { { body: { data: created[kind] }.to_json } } }
    stub_request(:get, %r{langfuse\.test/api/public/score-configs}).to_return(&listing.call(:config))
    stub_request(:get, %r{langfuse\.test/api/public/annotation-queues}).to_return(&listing.call(:queue))
    stub_request(:get, %r{langfuse\.test/api/public/unstable/dashboard-widgets}).to_return(&listing.call(:widgets))
    stub_request(:get, %r{langfuse\.test/api/public/unstable/dashboards}).to_return(&listing.call(:dashboard))
    stub_request(:patch, %r{langfuse\.test/api/public/unstable/dashboard-widgets/}).to_return(body: "{}")
    stub_request(:patch, %r{langfuse\.test/api/public/unstable/dashboards/}).to_return { |request| bodies[:layout] << request.body; { body: "{}" } }
    { bodies: bodies,
      create_config: stub_request(:post, "http://langfuse.test/api/public/score-configs").to_return(&creating.call(:config)),
      create_queue: stub_request(:post, "http://langfuse.test/api/public/annotation-queues").to_return(&creating.call(:queue)),
      create_widget: stub_request(:post, "http://langfuse.test/api/public/unstable/dashboard-widgets").to_return(&creating.call(:widgets)),
      create_dashboard: stub_request(:post, "http://langfuse.test/api/public/unstable/dashboards").to_return(&creating.call(:dashboard)) }
  end
end
