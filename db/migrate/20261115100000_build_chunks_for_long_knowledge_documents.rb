# Long knowledge documents saved before 20261115090000 have no sections yet, so the agent could neither read nor
# search them. Sections are built here and embedded in the background (EmbedJob).
class BuildChunksForLongKnowledgeDocuments < ActiveRecord::Migration[8.1]
  def up
    KnowledgeDocument.build_missing_chunks
  end

  def down
    # The sections belong to the documents and are removed with them
  end
end
