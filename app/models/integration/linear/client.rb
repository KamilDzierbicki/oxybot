# Linear's GraphQL API with a personal API key (header "Authorization: <key>", no Bearer prefix).
class Integration::Linear::Client
  URL = URI("https://api.linear.app/graphql")

  class Error < StandardError; end

  def initialize(api_key)
    @api_key = api_key
  end

  # Returns { id:, identifier:, url:, state: }
  def create_issue(team_id:, title:, description:)
    data = query(<<~GRAPHQL, input: { teamId: team_id, title: title, description: description })
      mutation($input: IssueCreateInput!) {
        issueCreate(input: $input) { success issue { id identifier url state { name type } } }
      }
    GRAPHQL
    issue = data.dig("issueCreate", "issue") or raise Error, "Linear did not create the issue"
    { id: issue["id"], identifier: issue["identifier"], url: issue["url"], state: issue.dig("state", "name") }
  end

  # Moves the issue to the team's first workflow state of the given type
  def move_issue(issue_id, team_id:, state_type:)
    states = query(<<~GRAPHQL, filter: { team: { id: { eq: team_id } }, type: { eq: state_type } }).dig("workflowStates", "nodes")
      query($filter: WorkflowStateFilter) { workflowStates(filter: $filter) { nodes { id name position } } }
    GRAPHQL
    state = states.min_by { |node| node["position"].to_f } or raise Error, "No #{state_type} state in the Linear team"
    query(<<~GRAPHQL, id: issue_id, input: { stateId: state["id"] })
      mutation($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success } }
    GRAPHQL
    state["name"]
  end

  private

  def query(graphql, **variables)
    response = Net::HTTP.post(URL, { query: graphql, variables: variables }.to_json,
                              "Content-Type" => "application/json", "Authorization" => @api_key)
    body = JSON.parse(response.body)
    raise Error, "Linear: #{body["errors"].map { |error| error["message"] }.join(", ")}" if body["errors"].present?
    raise Error, "Linear answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    body.fetch("data")
  end
end
