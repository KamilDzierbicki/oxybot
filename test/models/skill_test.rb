require "test_helper"

class SkillTest < ActiveSupport::TestCase
  test "a personal skill wins over the team skill of the same name" do
    skill, rest = Skill.invoked_in("/voc mobile app", users(:kamil))

    assert_equal skills(:kamil_voc), skill
    assert_equal "mobile app", rest
  end

  test "another account's skill is not available" do
    assert_nil Skill.invoked_in("/churn-risk", users(:kamil))
  end

  test "text without a slash command runs no skill" do
    assert_nil Skill.invoked_in("what about /voc?", users(:kamil))
  end

  test "the assistant follows the skill's instructions and gets the rest as the question" do
    conversation = users(:kamil).conversations.create!(account: accounts(:acme))

    conversation.ask("/voc PDF export")
    perform_enqueued_jobs(only: GenerateReplyJob)

    request = JSON.parse(llm_requests("openspark-spark").first.body)
    system = request["messages"].find { |message| message["role"] == "system" }["content"].to_s
    assert_includes system, "Use exactly three bullets."
    assert_equal "PDF export", request["messages"].reverse.find { |message| message["role"] == "user" }["content"].to_s
  end
end
