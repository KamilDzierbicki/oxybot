# Pendo product analytics for launch reviews: weekly unique identified visitors of the feature (Aggregation API).
# access_token is the integration key; settings["host"] is the domain the team signs in on (app.pendo.io,
# app.eu.pendo.io, ...); the feature's analytics key is a Pendo feature id.
class Integration::Pendo < Integration
  include Integration::Analytics

  HOSTS = %w[app.pendo.io app.eu.pendo.io us1.app.pendo.io app.jpn.pendo.io app.au.pendo.io].freeze

  store_accessor :settings, :host

  validates :host, inclusion: { in: HOSTS }, allow_blank: true

  def self.external_id_label = "Subscription name"
  def self.analytics_key_label = "Pendo feature id"

  def self.form_fields
    [ [ :host, "Pendo address you sign in on", :select, HOSTS.map { |host| [ host, host ] } ],
      [ :access_token, "Integration key (read-only is enough)", :password ] ]
  end

  def verify_connection
    body = Client.new(access_token, host).verify
    raise Integration::Http::Error, "the integration key is not valid" unless body["valid"]

    [ true, body["writeAccess"] ? "Pendo answered. The key can also write; a read-only key is enough." : "Pendo answered with a read-only key." ]
  end

  private

  def client
    mock? ? Integration::SampleUsage : Client.new(access_token, host)
  end
end
