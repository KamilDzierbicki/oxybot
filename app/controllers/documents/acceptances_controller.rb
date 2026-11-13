class Documents::AcceptancesController < ApplicationController
  include DocumentScoped

  def create
    suggestion = @document.suggestions.find(params[:suggestion_id])
    if suggestion.stale? && params[:confirm_stale] != "1"
      redirect_to @document, alert: "The document changed after the agent read it. Accepting would replace those edits; confirm to continue."
    else
      previous = @document.versions.last
      suggestion.accept(user: Current.user)
      undo = document_version_restoration_path(@document, previous) if previous
      redirect_to @document, notice: "Applied the agent's change.", flash: { undo: undo }.compact
    end
  end
end
