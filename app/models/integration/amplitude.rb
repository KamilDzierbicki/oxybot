# Amplitude product analytics for launch reviews: weekly unique users of the feature's event (Dashboard REST API).
# access_token is the project API key, secret the secret key; settings["region"] is "us" or "eu".
class Integration::Amplitude < Integration
  include Integration::Analytics

  store_accessor :settings, :region

  def self.external_id_label = "Project id"
  def self.analytics_key_label = "Amplitude event name"

  def self.form_fields
    [ [ :region, "Data center", :select, [ [ "United States", "us" ], [ "European Union", "eu" ] ] ],
      [ :access_token, "Project API key", :password ], [ :secret, "Project secret key", :password ] ]
  end

  def verify_connection
    client.weekly_users("_active", from: Date.yesterday, to: Date.yesterday)
    [ true, "Amplitude answered; the API key and secret key can read event segmentation." ]
  end

  private

  def client
    mock? ? Integration::SampleUsage : Client.new(access_token, secret, region)
  end
end
