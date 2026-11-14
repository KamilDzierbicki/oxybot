# Gong sales calls as feedback: what the customer side said, from call transcripts. access_token is the access key,
# secret the access key secret; base_url is the API address shown on Gong's API settings page (it differs per company).
class Integration::Gong < Integration
  include Integration::FeedbackSource

  store_accessor :settings, :base_url

  validate :base_url_allowed, if: -> { base_url.present? }

  def self.external_id_label = "Gong workspace or company name"

  def self.form_fields
    [ [ :base_url, "API base URL (Gong settings, API page)", :text ], [ :access_token, "Access key", :password ], [ :secret, "Access key secret", :password ] ]
  end

  def verify_connection
    client.ping
    [ true, "Gong answered; the access key can read calls." ]
  end

  private

  def client = mock? ? Integration::SampleFeedback.new(kind) : Client.new(base_url, access_token, secret)

  def base_url_allowed
    errors.add(:base_url, "must be an https address, like https://us-12345.api.gong.io") unless base_url.start_with?("https://") && Integration::OutboundUrl.allowed?(base_url)
  end
end
