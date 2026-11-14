class AiSettingsController < ApplicationController
  admin_only
  before_action :set_account

  def show
    load_page
  end

  def update
    if @account.update_ai_settings(params.expect(account: Account::AiSettings::DEFAULTS.keys).to_h)
      redirect_to ai_settings_path, notice: "AI settings saved."
    else
      load_page
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = Current.account
  end

  def load_page
    @models = Account::AiSettings.available_models
    @prompts = Prompt::NAMES.map { |name| Prompt.fetch(name) }
    @embedding_space = EmbeddingSpace.active
    @stale_vectors = @account.features.stale_embeddings.count + @account.insights.stale_embeddings.count
    @ai_spend_today = @account.ai_spend_today
  end
end
