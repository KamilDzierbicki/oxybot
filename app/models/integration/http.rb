# JSON over HTTPS for integration clients: timeouts, a readable error with the status, and no redirects followed.
module Integration::Http
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      super(message)
      @status = status
    end
  end

  module_function

  def get(url, headers: {}, params: {}) = request(Net::HTTP::Get, url, headers: headers, params: params)
  def post(url, body, headers: {}, form: false) = request(Net::HTTP::Post, url, headers: headers, body: body, form: form)

  def request(method, url, headers: {}, params: {}, body: nil, form: false)
    uri = URI(url)
    uri.query = [ uri.query, URI.encode_www_form(params) ].compact_blank.join("&").presence if params.any?
    request = method.new(uri, { "Accept" => "application/json" }.merge(headers))
    if body
      request["Content-Type"] = form ? "application/x-www-form-urlencoded" : "application/json"
      request.body = form ? URI.encode_www_form(body) : body.to_json
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 30) { |http| http.request(request) }
    raise Error.new("#{uri.host}#{uri.path} answered #{response.code}: #{response.body.to_s.truncate(200)}", status: response.code.to_i) unless response.is_a?(Net::HTTPSuccess)

    response.body.present? ? JSON.parse(response.body) : {}
  end

  def basic(user, password) = { "Authorization" => "Basic #{Base64.strict_encode64("#{user}:#{password}")}" }
  def bearer(token) = { "Authorization" => "Bearer #{token}" }
end
