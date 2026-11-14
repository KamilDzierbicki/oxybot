# Searches the sections of the workspace's long knowledge documents (short ones are already in the instructions).
# Given to the agents only when the workspace has a long document.
class SearchKnowledgeTool < ApplicationTool
  LIMIT = 5

  description "Searches the company's longer documents (strategy, pricing, personas, competitors) and returns matching sections."
  parameter :query, description: "What to look for, in a few words"

  def execute(query:)
    chunks = account.knowledge_chunks.includes(:knowledge_document).hybrid_search(query, limit: LIMIT)

    { passages: chunks.map { |chunk| { document: chunk.knowledge_document.title, section: chunk.heading, text: chunk.body }.compact } }
  end
end
