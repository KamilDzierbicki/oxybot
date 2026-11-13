# The account's code repository, read-only. The spec writer searches it for technical context.
# Mock mode (no token) reads the sample repository in config/mocks/github.
class Integration::Github < Integration
  store_accessor :settings, :repository

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
