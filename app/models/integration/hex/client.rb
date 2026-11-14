# Hex public API v1 (https://learn.hex.tech/docs/api-integrations/api/reference): bearer token, POST
# /v1/projects/{id}/runs runs the latest published version with input parameters and answers with a runUrl.
class Integration::Hex::Client
  def initialize(base_url, token)
    @base = "#{(base_url.presence || "https://app.hex.tech").delete_suffix("/")}/api/v1"
    @headers = Integration::Http.bearer(token)
  end

  def me = Integration::Http.get("#{@base}/users/me", headers: @headers)

  def run(project_id, **inputs)
    Integration::Http.post("#{@base}/projects/#{project_id}/runs", { inputParams: inputs }, headers: @headers).fetch("runUrl")
  end
end
