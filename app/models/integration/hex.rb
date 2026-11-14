# Hex for launch reviews. Hex's API can run a published project but cannot return its numbers (no endpoint gives a
# run's results), so the review links to a fresh run of the team's launch analysis instead of quoting figures.
# access_token is a workspace token with "Run projects"; project_id the published project; base_url the Hex host.
class Integration::Hex < Integration
  store_accessor :settings, :project_id, :base_url

  validates :project_id, format: { with: /\A[0-9a-f-]{8,64}\z/i, message: "is the id in the project's URL" }, allow_blank: true
  validate :base_url_allowed, if: -> { base_url.present? }

  def self.external_id_label = "Workspace name"

  def self.form_fields
    [ [ :project_id, "Published project id (inputs: feature, released_on)", :text ], [ :base_url, "Hex address (default https://app.hex.tech)", :text ],
      [ :access_token, "Workspace token with “Run projects”", :password ] ]
  end

  def verify_connection
    Client.new(base_url, access_token).me
    [ true, "Hex answered; the token is valid." ]
  end

  # A run of the launch analysis for this feature: its link, or nil in test mode or without a project
  def launch_run_url(feature)
    return if mock? || project_id.blank?

    Client.new(base_url, access_token).run(project_id, feature: feature.analytics_key.presence || feature.title, released_on: feature.released_at.to_date.iso8601)
  end

  private

  def base_url_allowed
    errors.add(:base_url, "must be an https address") unless base_url.start_with?("https://") && Integration::OutboundUrl.allowed?(base_url)
  end
end
