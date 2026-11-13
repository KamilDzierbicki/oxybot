# A connection of one account to an outside system (Slack workspace, HubSpot portal).
# Without an access token it runs in mock mode: Slack replies are only recorded, HubSpot data comes from
# config/mocks/hubspot.yml. Add the token and the same code calls the real API.
class Integration < ApplicationRecord
  belongs_to :account

  encrypts :access_token

  validates :external_id, presence: true, uniqueness: { scope: :type }

  # Every kind shares the integrations routes and params (integration_path, params[:integration])
  def self.model_name = ActiveModel::Name.new(self, nil, "Integration")

  KINDS = { "slack" => "Integration::Slack", "mattermost" => "Integration::Mattermost", "hubspot" => "Integration::Hubspot",
            "linear" => "Integration::Linear", "github" => "Integration::Github" }.freeze

  store_accessor :settings, :last_check_ok, :last_check_message, :last_checked_at

  def self.class_for(kind) = KINDS.fetch(kind.to_s).constantize

  # What external_id means for this kind, shown on the connect form
  def self.external_id_label = "Id"

  def mock? = access_token.blank?

  # Calls the service with the saved token and remembers the result. Returns [ok, message].
  def check_connection
    ok, message = mock? ? [ true, "Mock mode: no token saved, so nothing was called." ] : verify_connection
    update!(last_check_ok: ok, last_check_message: message, last_checked_at: Time.current.iso8601)
    [ ok, message ]
  rescue StandardError => e
    raise unless e.is_a?(Net::OpenTimeout) || e.is_a?(SocketError) || e.class.name.end_with?("::Error")

    update!(last_check_ok: false, last_check_message: e.message, last_checked_at: Time.current.iso8601)
    [ false, e.message ]
  end

  def kind = type.demodulize.downcase

  def display_name = { "slack" => "Slack", "mattermost" => "Mattermost", "hubspot" => "HubSpot", "linear" => "Linear", "github" => "GitHub" }.fetch(kind)

  def chat? = is_a?(Integration::Chat)
end
