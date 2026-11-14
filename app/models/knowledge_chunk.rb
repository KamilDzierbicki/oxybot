# One section of a long knowledge document, searched by the agent's search_knowledge tool instead of being sent in
# every prompt. The document title and heading go into the vector too, so a section keeps its context when it is
# found on its own.
class KnowledgeChunk < ApplicationRecord
  include Embeddable, HybridSearchable

  belongs_to :account
  belongs_to :knowledge_document

  def embedding_text = [ "#{knowledge_document.title}: #{heading}".delete_suffix(": "), body ].join("\n")
end
