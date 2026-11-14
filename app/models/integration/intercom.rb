# Intercom conversations as feedback: customer-written messages of conversations updated since the last sync,
# optionally only those with a tag. access_token is a private app access token.
class Integration::Intercom < Integration
  include Integration::FeedbackSource

  store_accessor :settings, :tag

  def self.external_id_label = "Workspace id"

  def self.form_fields
    [ [ :tag, "Only conversations with this tag id (optional)", :text ], [ :access_token, "Access token", :password ] ]
  end

  def verify_connection
    me = Client.new(access_token).me
    [ true, "Intercom answered as #{me["email"] || me["name"]} (workspace #{me.dig("app", "name")})." ]
  end

  private

  def client = mock? ? Integration::SampleFeedback.new(kind) : Client.new(access_token, tag: tag)
end
