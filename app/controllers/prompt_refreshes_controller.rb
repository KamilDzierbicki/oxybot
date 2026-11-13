class PromptRefreshesController < ApplicationController
  admin_only

  def create
    Prompt.refresh
    redirect_to ai_settings_path, notice: "Prompts reloaded from Langfuse."
  end
end
