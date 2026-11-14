# Zendesk Support tickets with a tag (default "feedback") as feedback. Zendesk is retiring API tokens, so this
# uses an OAuth client with the client credentials grant: access_token is the client id, secret the client secret,
# and the subdomain is the external id.
class Integration::Zendesk < Integration
  include Integration::FeedbackSource

  store_accessor :settings, :tag

  validates :external_id, format: { with: /\A[a-z0-9][a-z0-9-]*\z/, message: "is the subdomain only, like acme for acme.zendesk.com" }

  def self.external_id_label = "Subdomain (acme for acme.zendesk.com)"

  def self.form_fields
    [ [ :tag, "Tag that marks feedback tickets", :text ], [ :access_token, "OAuth client id", :password ], [ :secret, "OAuth client secret", :password ] ]
  end

  def tag = super.presence || "feedback"

  def verify_connection
    user = client.me.fetch("user")
    raise Integration::Http::Error, "Zendesk answered without a signed-in agent" unless user["id"] && %w[agent admin].include?(user["role"])

    [ true, "Zendesk answered as #{user["email"]} (#{user["role"]})." ]
  end

  private

  def client = mock? ? Integration::SampleFeedback.new(kind) : Client.new(external_id, access_token, secret, tag: tag)
end
