# Company context for the agent: strategy, personas, pricing, competitors. A short document goes into the
# instructions in full; a long one is split into sections the agent searches with search_knowledge, so it costs
# prompt space only when a question needs it.
class KnowledgeDocument < ApplicationRecord
  # About 1,000 tokens: above this a document would crowd every prompt
  IN_PROMPT_LIMIT = 4_000
  # About 300 tokens per section: small enough to find one topic, large enough to keep its sentences together
  CHUNK_SIZE = 1_200

  belongs_to :account
  has_many :chunks, -> { order(:position) }, class_name: "KnowledgeChunk", dependent: :delete_all

  normalizes :title, :body, with: ->(text) { VisibleText.clean(text) }

  validates :title, :body, presence: true

  after_save_commit :rebuild_chunks, if: -> { saved_change_to_title? || saved_change_to_body? }

  scope :alphabetically, -> { order(:title, :id) }

  def long? = body.to_s.length > IN_PROMPT_LIMIT

  # Embeds the sections in batches of one embedding call each (EmbedJob)
  def embed
    chunks.includes(:knowledge_document).each_slice(ReembedJob::BATCH) { |batch| KnowledgeChunk.embed_all(batch) }
  end

  # Replaces the sections with the current text's, or removes them when the document is short. Saving does this on
  # its own; an evaluation calls it directly, because its transaction never commits.
  def build_chunks
    transaction do
      chunks.delete_all
      next unless long?

      section_texts.each_with_index do |section, position|
        chunks.create!(account: account, position: position, heading: section[:heading], body: section[:body])
      end
    end
  end

  # Sections under the nearest markdown heading, packed paragraph by paragraph up to CHUNK_SIZE. A paragraph that is
  # too long alone is split at sentence ends, and a sentence that is too long alone at the size limit, so no text is
  # dropped.
  def section_texts
    sections = [ [ nil, [] ] ]
    body.to_s.each_line do |line|
      if (heading = line[/\A\#{1,6}\s+(.+)/, 1])
        sections << [ heading.strip, [] ]
      else
        sections.last.last << line
      end
    end

    sections.flat_map do |heading, lines|
      pieces = lines.join.split(/\n\s*\n/).map(&:strip).reject(&:empty?).flat_map { |paragraph| fit(paragraph) }
      pack(pieces).map { |text| { heading: heading, body: text } }
    end
  end

  private

  def rebuild_chunks
    build_chunks
    EmbedJob.perform_later(self) if long?
  end

  def fit(paragraph)
    return [ paragraph ] if paragraph.length <= CHUNK_SIZE

    pack(paragraph.split(/(?<=[.!?])\s+/).flat_map { |sentence| sentence.scan(/.{1,#{CHUNK_SIZE}}/m) }, separator: " ")
  end

  def pack(pieces, separator: "\n\n")
    pieces.each_with_object([]) do |piece, packed|
      if packed.any? && packed.last.length + separator.length + piece.length <= CHUNK_SIZE
        packed.last << separator << piece
      else
        packed << piece.dup
      end
    end
  end
end
