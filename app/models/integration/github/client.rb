# GitHub REST API (code search and file contents) with a fine-grained, read-only token.
class Integration::Github::Client
  BASE_URL = "https://api.github.com"

  class Error < StandardError; end

  def initialize(token, repository)
    @token = token
    @repository = repository
  end

  # Returns [{ path:, snippet: }]; GitHub's code search matches the words, so the query is reduced to them
  def search_code(query)
    words = query.to_s.scan(/[[:alnum:]_]{3,}/).first(5).join(" ")
    body = get("/search/code", q: "#{words} repo:#{@repository}", per_page: 10)
    body.fetch("items").map do |item|
      { path: item["path"], snippet: item.fetch("text_matches", []).map { |match| match["fragment"] }.join(" ... ").presence || item["name"] }
    end
  end

  def read_file(path)
    body = get("/repos/#{@repository}/contents/#{path.delete_prefix("/")}")
    Base64.decode64(body.fetch("content")).force_encoding("UTF-8")
  end

  private

  def get(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?
    response = Net::HTTP.get_response(uri, "Authorization" => "Bearer #{@token}", "Accept" => "application/vnd.github.text-match+json",
                                           "X-GitHub-Api-Version" => "2022-11-28")
    raise Error, "GitHub #{path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
