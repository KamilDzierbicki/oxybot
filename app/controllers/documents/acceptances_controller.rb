class Documents::AcceptancesController < ApplicationController
  include DocumentScoped

  def create
    suggestion = @document.suggestions.find(params[:suggestion_id])
    if suggestion.stale? && params[:confirm_stale] != "1"
      redirect_to @document, alert: "The document changed after the agent read it. Accepting would replace those edits; confirm to continue."
    else
      suggestion.accept(user: Current.user)
      redirect_to @document, notice: "Suggestion applied."
    end
  end
end
