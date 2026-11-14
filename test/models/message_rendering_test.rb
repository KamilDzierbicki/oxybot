require "test_helper"

class MessageRenderingTest < ActiveSupport::TestCase
  test "a reply rendered by a background job still shows citation previews from its own workspace" do
    account = accounts(:acme)
    insight = account.feedback_notes.create!(source: "manual", body: "x", customer: customers(:northwind))
                     .insights.create!(account: account, product: products(:reports), quote: "Board wants PDFs", summary: "PDF",
                                       customer: customers(:northwind))
    conversation = account.conversations.create!(user: users(:kamil), channel: "web")
    reply = conversation.messages.create!(role: "assistant", status: "done", content: "Needed [insight:#{insight.id}]")

    Current.reset # jobs run outside a request
    html = ApplicationController.render(partial: "messages/message", locals: { message: reply })

    assert_includes html, "popovertarget"
    assert_includes html, "Board wants PDFs"
  end
end
