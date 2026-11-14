require "test_helper"

# litellm.yaml is part of the app's behavior: every model OxyBot calls must have somewhere to go when it fails,
# and the CI config must serve every alias the CI evaluations call.
class LitellmConfigTest < ActiveSupport::TestCase
  test "every paid alias falls back to another alias that exists" do
    config = YAML.load_file(Rails.root.join("litellm.yaml"))
    aliases = config["model_list"].map { |model| model["model_name"] }
    paid = config["model_list"].reject { |model| model.dig("litellm_params", "model").start_with?("ollama/") }.map { |model| model["model_name"] }
    fallbacks = config.dig("router_settings", "fallbacks").reduce({}, :merge)

    assert_empty paid - fallbacks.keys, "a paid alias without a fallback fails with its provider"
    fallbacks.each do |name, targets|
      assert_empty targets - aliases, "#{name} falls back to an alias LiteLLM does not serve"
      assert_not_includes targets, name
    end
  end

  test "the CI LiteLLM serves every alias the CI evaluations call, each with a spend cap" do
    ci = YAML.load_file(Rails.root.join("litellm.ci.yaml"))["model_list"]
    served = ci.map { |model| model["model_name"] }
    needed = [ Evaluation::Baseline.new.model, InjectionJudge::MODEL, Account::AiSettings::DEFAULTS["model_extract"], "oxybot-embed" ]

    assert_empty needed.compact - served
    ci.reject { |model| model.dig("litellm_params", "model").start_with?("ollama/") }.each do |model|
      assert model.dig("litellm_params", "max_budget"), "#{model["model_name"]} has no spend cap in CI"
    end
  end
end
