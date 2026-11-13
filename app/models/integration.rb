# A connection of one account to an outside system (Slack workspace, HubSpot portal).
# Without an access token it runs in mock mode: Slack replies are only recorded, HubSpot data comes from
# config/mocks/hubspot.yml. Add the token and the same code calls the real API.
class Integration < ApplicationRecord
  belongs_to :account

  encrypts :access_token

  validates :external_id, presence: true, uniqueness: { scope: :type }

  # Every kind shares the integrations routes and params (integration_path, params[:integration])
  def self.model_name = ActiveModel::Name.new(self, nil, "Integration")

  def mock? = access_token.blank?

  def kind = type.demodulize.downcase

  def display_name = { "slack" => "Slack", "hubspot" => "HubSpot", "linear" => "Linear", "github" => "GitHub" }.fetch(kind)
end
