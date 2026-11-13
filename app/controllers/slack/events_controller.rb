# Slack Events API endpoint. Slack signs every request with the app's signing secret; anything unsigned,
# tampered with or older than five minutes (a replay) is refused before the body is read as data.
# The work happens in a job: Slack wants an answer within three seconds.
class Slack::EventsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  before_action :verify_signature

  def create
    payload = JSON.parse(request.raw_post)

    case payload["type"]
    when "url_verification"
      render json: { challenge: payload["challenge"] }
    when "event_callback"
      Integration::Slack.find_by(external_id: payload["team_id"])&.receive(payload["event"])
      head :ok
    else
      head :ok
    end
  end

  private

  def verify_signature
    timestamp = request.headers["X-Slack-Request-Timestamp"].to_i
    signature = request.headers["X-Slack-Signature"].to_s
    expected = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", signing_secret, "v0:#{timestamp}:#{request.raw_post}")}"

    head :unauthorized unless (Time.current.to_i - timestamp).abs < 5.minutes && ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  def signing_secret
    ENV.fetch("SLACK_SIGNING_SECRET") { Rails.env.production? ? raise("SLACK_SIGNING_SECRET is not set") : "oxybot-local-signing-secret" }
  end
end
