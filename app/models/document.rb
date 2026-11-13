# A product document the agent drafts and people refine: a spec for a feature, a voice-of-customer report,
# the weekly opportunity report, release notes or a launch review. Every change is a version, and the agent
# never edits in place: it proposes a suggestion that a person accepts (unless auto_accept is on).
class Document < ApplicationRecord
  KINDS = {
    "prd" => "Product spec",
    "voc_report" => "Voice of customer report",
    "opportunity_report" => "Opportunity report",
    "release_notes" => "Release notes",
    "launch_review" => "Launch review"
  }.freeze
  STATUSES = %w[drafting ready failed].freeze

  belongs_to :account
  belongs_to :feature, optional: true
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :document_template, optional: true
  has_many :versions, -> { order(:id) }, class_name: "DocumentVersion", dependent: :destroy
  has_many :suggestions, -> { order(:id) }, class_name: "DocumentSuggestion", dependent: :destroy

  validates :title, presence: true
  validates :body, presence: true, if: -> { status == "ready" }
  validates :kind, inclusion: { in: KINDS.keys }
  validates :status, inclusion: { in: STATUSES }

  broadcasts_refreshes

  scope :latest_first, -> { order(updated_at: :desc, id: :desc) }
  scope :specs, -> { where(kind: "prd") }
  scope :ready, -> { where(status: "ready") }

  # Builds a document of a kind with the account's template for it, and drafts it in the background
  def self.draft(account:, kind:, creator: nil, feature: nil, title: nil)
    template = account.document_templates.where(kind: kind).order(:id).first
    document = account.documents.create!(kind: kind, creator: creator, feature: feature, document_template: template,
                                         title: title || default_title(kind, feature, today: Time.current.in_time_zone(account.time_zone).to_date))
    document.generate_later
    document
  end

  def self.default_title(kind, feature, today: Date.current)
    case kind
    when "prd" then "Spec: #{feature.title}"
    when "launch_review" then "Launch review: #{feature.title}"
    when "opportunity_report" then "Opportunities, week of #{today.beginning_of_week.to_fs(:long)}"
    when "release_notes" then "Release notes, #{today.to_fs(:long)}"
    else "#{KINDS.fetch(kind)}, #{today.to_fs(:long)}"
    end
  end

  def kind_name = KINDS.fetch(kind)
  def drafting? = status == "drafting"
  def ready? = status == "ready"

  def generate_later
    GenerateDocumentJob.perform_later(self)
  end

  def generate
    Document::Generation.new(self).run
  end

  # A person's edit, or an accepted suggestion: the body changes and a version records who and why
  def edit(new_body, user:, summary:)
    transaction do
      cited = account.insights.where(id: new_body.scan(Message::CITATION).flatten.map(&:to_i)).pluck(:id)
      update!(body: new_body, cited_insight_ids: cited)
      versions.create!(body: new_body, user: user, summary: summary)
    end
  end

  def request_change(instruction, user:)
    suggestion = suggestions.create!(instruction: instruction, user: user, base_version: versions.last)
    suggestion.generate_later
    suggestion
  end

  # The "## Success metrics" (or "Goals") section, used by the launch review to measure the outcome
  def section(*names)
    pattern = /^##+\s*(#{names.map { |name| Regexp.escape(name) }.join("|")})[^\n]*\n(.*?)(?=^##\s|\z)/im
    body[pattern, 2]&.strip
  end
end
