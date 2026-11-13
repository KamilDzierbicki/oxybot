require "test_helper"

class PromptTest < ActiveSupport::TestCase
  LANGFUSE = "http://langfuse.test"

  teardown { Rails.cache.clear }

  test "without Langfuse the file is used and variables are filled" do
    text = Prompt.render("feature-judge", insight_summary: "PDF export", insight_quote: "q", candidates: "- [1] PDF")

    assert_includes text, "Insight: PDF export"
    assert_not_includes text, "{{"
  end

  test "empty optional sections leave no gaps" do
    text = Prompt.render("product-agent", account_name: "Acme", user_name: "Kamil", products: "- reports")

    assert_no_match(/\n{3,}/, text)
  end

  test "with Langfuse the production version is used and cached" do
    with_langfuse do
      request = stub_request(:get, "#{LANGFUSE}/api/public/v2/prompts/feature-judge?label=production")
                  .to_return(body: { name: "feature-judge", type: "text", version: 7, prompt: "From Langfuse: {{insight_summary}}" }.to_json)

      2.times { assert_equal "From Langfuse: PDF", Prompt.render("feature-judge", insight_summary: "PDF") }
      assert_equal "feature-judge@v7", Prompt.version_tag("feature-judge")
      assert_requested request, times: 1
    end
  end

  test "when Langfuse is down the file keeps the app working" do
    with_langfuse do
      stub_request(:get, %r{#{LANGFUSE}/api/public/v2/prompts/}).to_return(status: 503)

      assert_equal "file", Prompt.fetch("feature-judge").source
    end
  end

  private

  def with_langfuse
    original = ENV.slice("LANGFUSE_URL", "LANGFUSE_PUBLIC_KEY", "LANGFUSE_SECRET_KEY")
    ENV.update("LANGFUSE_URL" => LANGFUSE, "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk")
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    %w[LANGFUSE_URL LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY].each { |key| original.key?(key) ? ENV[key] = original[key] : ENV.delete(key) }
    Rails.cache = ActiveSupport::Cache::NullStore.new
  end
end
