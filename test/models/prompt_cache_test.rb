require "test_helper"

# Anthropic caches a prompt prefix that is byte-for-byte the same; LiteLLM marks each system message for caching.
class PromptCacheTest < ActiveSupport::TestCase
  test "the assistant's stable prompt is its own first system message, the same for every user, channel and skill" do
    first = system_messages(users(:kamil), "What do customers say about PDF export?")
    second = system_messages(users(:mia), "/voc reporting")

    assert_equal 2, first.size, "a stable and a per-request system message"
    assert_equal first.first, second.first, "nothing personal or per-request may sit in the cached part"
    assert_includes first.first, "Products:"
    assert_includes first.last, users(:kamil).name
    assert_not_includes first.first, users(:kamil).name
  end

  test "a prompt version without the marker is one system message, as before" do
    assert_equal [ "Just one part", "" ], Prompt.split_parts("Just one part")
    assert_equal [ "Stable", "Per request" ], Prompt.split_parts("Stable\n--- per request ---\nPer request")
  end

  private

  def system_messages(user, question)
    conversation = user.conversations.create!(account: accounts(:acme))
    conversation.ask(question)
    perform_enqueued_jobs(only: GenerateReplyJob)
    body = JSON.parse(llm_requests(accounts(:acme).ai_model("assistant")).last.body)
    body["messages"].select { |message| message["role"] == "system" }.map { |message| message["content"].is_a?(Array) ? message["content"].map { |part| part["text"] }.join : message["content"] }
  end
end
