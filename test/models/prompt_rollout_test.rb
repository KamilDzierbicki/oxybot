require "test_helper"

# A candidate prompt version reaches a share of workspaces (or requests) first; its traces name the variant and its
# model calls link the candidate version, so its scores can be compared with production before everyone gets it.
class PromptRolloutTest < ActiveSupport::TestCase
  include TracingTestHelper

  setup { Rails.cache = ActiveSupport::Cache::MemoryStore.new }
  teardown { Rails.cache = ActiveSupport::Cache::NullStore.new }

  test "by workspace, the share decides how many workspaces get the candidate, and each keeps its answer" do
    rollout = PromptRollout.create!(prompt_name: "product-agent", share: 30)
    accounts = (1..400).map { |id| Account.new(id: id) }

    served = accounts.count { |account| rollout.serves?(account) }
    assert_in_delta 120, served, 30
    assert accounts.first(50).all? { |account| rollout.serves?(account) == rollout.serves?(account) }, "a workspace does not flip between requests"
    assert_empty PromptRollout.versions_for(accounts.find { |account| !rollout.serves?(account) })
    assert_equal({ "product-agent" => "candidate" }, PromptRollout.versions_for(accounts.find { |account| rollout.serves?(account) }))

    rollout.update!(share: 0)
    assert accounts.none? { |account| PromptRollout.versions_for(account).any? }, "share 0 stops the rollout"
  end

  test "by request, the same workspace gets either version" do
    rollout = PromptRollout.create!(prompt_name: "product-agent", share: 50, unit: "request")

    assert_equal [ false, true ], Array.new(200) { rollout.serves?(accounts(:acme)) }.uniq.sort_by { |served| served ? 1 : 0 }
  end

  test "production cannot be the candidate, and the share stays a percentage" do
    assert_not PromptRollout.new(prompt_name: "product-agent", label: "production", share: 10).valid?
    assert_not PromptRollout.new(prompt_name: "product-agent", share: 101).valid?
    assert_not PromptRollout.new(prompt_name: "no-such-prompt", share: 10).valid?
  end

  test "a request in the rollout runs the candidate version and its trace says so" do
    start_tracing
    PromptRollout.create!(prompt_name: "feature-judge", share: 100)
    embed_features
    insight = accounts(:acme).feedback_notes.create!(source: "manual", body: "x")
                             .insights.create!(account: accounts(:acme), product: products(:reports), quote: "PDF please", summary: "PDF export")
    with_langfuse do
      stub_request(:get, %r{langfuse\.test/api/public/v2/prompts/}).to_return(status: 404, body: "{}")
      stub_request(:get, "http://langfuse.test/api/public/v2/prompts/feature-judge?label=candidate")
        .to_return(body: { type: "text", version: 9, prompt: Prompt.from_file("feature-judge").text, config: {} }.to_json)

      insight.match
    end

    root = finished_spans.find { |span| span.name == "match-insight" }
    assert_equal "feature-judge@candidate", root.attributes["langfuse.trace.metadata.prompt_variant"]
    model_call = finished_spans.find { |span| span.hex_trace_id == root.hex_trace_id && span.attributes["gen_ai.operation.name"] == "chat" }
    assert_equal 9, model_call.attributes["langfuse.observation.prompt.version"], "scores on this call split by the candidate's version"
  ensure
    stop_tracing
  end

  test "a candidate label missing in Langfuse serves production, not the files" do
    with_langfuse do
      stub_request(:get, "http://langfuse.test/api/public/v2/prompts/feature-judge?label=candidate").to_return(status: 404, body: "{}")
      stub_request(:get, "http://langfuse.test/api/public/v2/prompts/feature-judge?label=production")
        .to_return(body: { type: "text", version: 4, prompt: "Production text", config: {} }.to_json)

      template = Prompt.using({ "feature-judge" => "candidate" }) { Prompt.fetch("feature-judge") }

      assert_equal [ "langfuse", 4 ], [ template.source, template.version ]
      assert_not Rails.cache.read(Prompt::UNREACHABLE_KEY), "other prompts keep using Langfuse"
    end
  end
end
