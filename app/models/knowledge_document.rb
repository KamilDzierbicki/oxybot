# Company context the assistant always gets: strategy, personas, pricing, competitors.
# Every document goes into the instructions in full, so keep them short; long sources need chunking first.
class KnowledgeDocument < ApplicationRecord
  belongs_to :account

  normalizes :title, :body, with: ->(text) { VisibleText.clean(text) }

  validates :title, :body, presence: true

  scope :alphabetically, -> { order(:title, :id) }
end
