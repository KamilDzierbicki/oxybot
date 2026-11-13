# A NUL byte in a parameter makes Postgres refuse the string and Rails answer 500. It is never valid text,
# so such requests are refused with 400 before they reach a controller.
class NullByteFilter
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    if contains_null?(request.query_string) || contains_null?(form_body(request))
      return [ 400, { "content-type" => "text/plain" }, [ "Bad request" ] ]
    end

    @app.call(env)
  end

  private

  def form_body(request)
    return "" unless request.media_type.to_s.start_with?("application/x-www-form-urlencoded", "multipart/form-data", "application/json")

    body = request.body.read
    request.body.rewind
    body
  end

  def contains_null?(text)
    text.to_s.include?("%00") || text.to_s.include?("\u0000") || text.to_s.include?("\\u0000")
  end
end
