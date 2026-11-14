require "test_helper"

class KnowledgeDocumentsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:kamil) }

  test "the knowledge page says which documents are always read and which are searched" do
    accounts(:acme).knowledge_documents.create!(title: "Strategy", body: "Win mid-market logistics in 2027.")
    accounts(:acme).knowledge_documents.create!(title: "Handbook", body: "Plans and prices.\n\n" + ("Every plan is billed per workspace. " * 150))

    get knowledge_documents_path

    assert_select ".card", text: /Strategy.*Always in the agent's context/m
    assert_select ".card", text: /Handbook.*Long document: searched in \d+ sections/m
  end
end
