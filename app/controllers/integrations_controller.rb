class IntegrationsController < ApplicationController
  admin_only except: %i[index show]
  before_action :set_integration, only: %i[show update destroy]

  def index
    @integrations = Current.account.integrations.index_by(&:kind)
  end

  def show
    # The log can hold private messages, so only admins see it, and only while testing in mock mode
    @chat_messages = @integration.chat_messages.chronologically.last(60) if @integration.chat? && @integration.mock? && Current.user.admin?
  end

  def new
    return head :not_found unless Integration::KINDS.key?(params[:kind])

    @integration = Current.account.integrations.new(type: Integration.class_for(params[:kind]).name)
  end

  def create
    return head :not_found unless Integration::KINDS.key?(params.dig(:integration, :kind))

    @integration = Integration.class_for(params.dig(:integration, :kind)).new(account: Current.account, external_id: params.dig(:integration, :external_id))
    @integration.assign_attributes(integration_params.except(:external_id))
    if @integration.save
      redirect_to @integration, notice: "#{@integration.display_name} connected#{" in mock mode (no token yet)" if @integration.mock?}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # The workspace id is fixed once connected: changing it would let one account claim another's events
  def update
    if @integration.update(integration_params.except(:external_id))
      redirect_to @integration
    else
      redirect_to @integration, alert: @integration.errors.full_messages.to_sentence
    end
  end

  def destroy
    @integration.destroy!
    redirect_to integrations_path, notice: "#{@integration.display_name} disconnected."
  end

  private

  def set_integration
    @integration = Current.account.integrations.find(params[:id])
  end

  def integration_params
    attributes = params.expect(integration: %i[external_id access_token webhook_secret command_token feedback_channel_ids app_user_id report_channel_id
                                              arr_property plan_property team_id repository server_url trigger_word])
    attributes[:feedback_channel_ids] = attributes[:feedback_channel_ids].to_s.split(/[\s,]+/).compact_blank if attributes.key?(:feedback_channel_ids)
    # An empty secret field keeps the stored value
    attributes.delete(:access_token) if attributes[:access_token].blank?
    attributes.delete(:webhook_secret) if attributes[:webhook_secret].blank?
    attributes.delete(:command_token) if attributes[:command_token].blank?
    attributes
  end
end
