class AiSettingsController < ApplicationController
  admin_only

  def show
    @account = Current.account
    @models = Account::AiSettings.available_models
    @prompts = Prompt::NAMES.map { |name| Prompt.fetch(name) }
  end

  def update
    @account = Current.account
    @account.time_zone = params.dig(:account, :time_zone) if params.dig(:account, :time_zone).present?
    if @account.update_ai_settings(params.expect(account: Account::AiSettings::DEFAULTS.keys).to_h)
      redirect_to ai_settings_path
    else
      @models = Account::AiSettings.available_models
      @prompts = Prompt::NAMES.map { |name| Prompt.fetch(name) }
      render :show, status: :unprocessable_entity
    end
  end
end
