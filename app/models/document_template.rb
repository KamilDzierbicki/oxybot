# The skeleton the agent fills for a kind of document (headings and short guidance), editable per account
class DocumentTemplate < ApplicationRecord
  belongs_to :account
  has_many :documents, dependent: :nullify

  validates :name, :body, presence: true
  validates :kind, inclusion: { in: Document::KINDS.keys }

  scope :ordered, -> { order(:kind, :name) }

  DEFAULTS_PATH = Rails.root.join("config/document_templates")

  # The built-in template of a kind (config/document_templates), used when an account has none of its own
  def self.default_body(kind)
    DEFAULTS_PATH.join("#{kind}.md").read
  end

  def self.install_defaults(account)
    Document::KINDS.each do |kind, name|
      account.document_templates.find_or_create_by!(kind: kind) do |template|
        template.name = "#{name} (default)"
        template.body = default_body(kind)
      end
    end
  end
end
