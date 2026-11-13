# The account's code repository, read-only. The spec writer searches it for technical context.
# Mock mode (no token) reads the sample repository in config/mocks/github.
class Integration::Github < Integration
  store_accessor :settings, :repository

  def self.external_id_label = "Repository as owner/name"

  before_validation { self.repository = external_id if repository.blank? }

  def verify_connection
    repo = Integration::Github::Client.new(access_token, repository).repository_info
    [ true, "Can read #{repo["full_name"]} (#{repo["private"] ? "private" : "public"})." ]
  end

  def search_code(query)
    client.search_code(query)
  end

  def read_file(path)
    client.read_file(path)
  end

  private

  def client
    mock? ? Integration::Github::MockClient.new : Integration::Github::Client.new(access_token, repository)
  end
end
