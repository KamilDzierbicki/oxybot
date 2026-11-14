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

  test "a model call names the Langfuse prompt version it was built from" do
    stub_request(:get, /langfuse\.test\/api\/public\/v2\/prompts\/feature-judge/)
      .to_return(body: { type: "text", prompt: Prompt.from_file("feature-judge").text, version: 4 }.to_json)
    Rails.cache.clear
    insight = accounts(:acme).insights.new(product: products(:reports), summary: "PDF export", quote: "PDF export please")

    with_langfuse { insight.judge(products(:reports).features.to_a) }

    model_call = finished_spans.find { |span| span.attributes["gen_ai.operation.name"] == "chat" }
    assert_equal [ "feature-judge", 4 ], model_call.attributes.values_at("langfuse.observation.prompt.name", "langfuse.observation.prompt.version")
  end
end
