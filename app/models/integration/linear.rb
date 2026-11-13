# The account's Linear workspace (external_id is the organization id). A feature is sent as an issue, and
# its status then syncs both ways: Linear's webhook moves the feature, a status change here moves the issue.
class Integration::Linear < Integration
  # Linear groups workflow states into types; each type maps to one feature status
  STATUS_BY_STATE_TYPE = {
    "triage" => "idea", "backlog" => "idea", "unstarted" => "planned",
    "started" => "in_progress", "completed" => "released", "canceled" => "idea"
  }.freeze
  STATE_TYPE_BY_STATUS = { "idea" => "backlog", "planned" => "unstarted", "in_progress" => "started", "released" => "completed" }.freeze

  encrypts :webhook_secret

  store_accessor :settings, :team_id, :mock_issues

  def self.external_id_label = "Organization id (Settings, Workspace, General)"

  def verify_connection
    organization = Integration::Linear::Client.new(access_token).organization
    return [ false, "The key belongs to organization #{organization["id"]}, not #{external_id}." ] if organization["id"] != external_id

    [ true, "Connected to #{organization["name"]}." ]
  end

  def create_issue(title:, description:)
    client.create_issue(team_id: team_id, title: title, description: description)
  end

  def move_issue(issue_id, status)
    client.move_issue(issue_id, team_id: team_id, state_type: STATE_TYPE_BY_STATUS.fetch(status))
  end

  # Handles one verified webhook payload: an issue linked to a feature changed its workflow state
  def receive(payload)
    return unless payload["type"] == "Issue" && payload["action"] == "update"

    data = payload["data"] || {}
    feature = account.features.find_by(linear_issue_id: data["id"])
    feature&.apply_linear_state(type: data.dig("state", "type"), name: data.dig("state", "name"))
  end

  # Mock mode only: plays what Linear would do when someone moves the issue, through the same path as a webhook
  def simulate_state_change(feature, state_type)
    client.set_state(feature.linear_issue_id, state_type)
    receive("type" => "Issue", "action" => "update",
            "data" => { "id" => feature.linear_issue_id, "state" => { "type" => state_type, "name" => state_type.humanize } })
  end

  private

  def client
    mock? ? Integration::Linear::MockClient.new(self) : Integration::Linear::Client.new(access_token)
  end
end
