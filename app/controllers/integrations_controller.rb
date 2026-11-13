class IntegrationsController < ApplicationController
  before_action :set_integration, only: %i[show update]

  def index
    @slack = Current.account.slack_integration
    @hubspot = Current.account.hubspot_integration
  end

  def show
    @slack_messages = @integration.slack_messages.chronologically.last(60) if @integration.is_a?(Integration::Slack)
  end

  def update
    @integration.update!(integration_params)
    redirect_to @integration, notice: "Settings saved."
  end

  private

  def set_integration
    @integration = Current.account.integrations.find(params[:id])
  end

  def integration_params
    attributes = params.expect(integration: %i[access_token feedback_channel_ids app_user_id arr_property plan_property])
    attributes[:feedback_channel_ids] = attributes[:feedback_channel_ids].to_s.split(/[\s,]+/).compact_blank if attributes.key?(:feedback_channel_ids)
    attributes.delete(:access_token) if attributes[:access_token].blank? # an empty field keeps the stored token
    attributes
  end
end
