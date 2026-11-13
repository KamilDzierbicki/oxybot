# Stands in for Linear until an API key is set: issues live in the integration's settings.
class Integration::Linear::MockClient
  STATE_NAMES = { "triage" => "Triage", "backlog" => "Backlog", "unstarted" => "Todo", "started" => "In Progress",
                  "completed" => "Done", "canceled" => "Canceled" }.freeze

  def initialize(integration)
    @integration = integration
  end

  def create_issue(team_id:, title:, description:)
    issues = @integration.mock_issues || {}
    number = issues.size + 1
    id = SecureRandom.uuid
    issues[id] = { "identifier" => "OXY-#{number}", "title" => title, "state" => "backlog" }
    @integration.update!(mock_issues: issues)
    { id: id, identifier: "OXY-#{number}", url: "https://linear.app/mock/issue/OXY-#{number}", state: STATE_NAMES["backlog"] }
  end

  def move_issue(issue_id, team_id:, state_type:)
    set_state(issue_id, state_type)
    STATE_NAMES.fetch(state_type)
  end

  def set_state(issue_id, state_type)
    issues = @integration.mock_issues || {}
    issues[issue_id] = (issues[issue_id] || {}).merge("state" => state_type)
    @integration.update!(mock_issues: issues)
  end
end
