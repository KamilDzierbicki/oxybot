class Documents::SuggestionsController < ApplicationController
  include DocumentScoped

  def create
    @document.request_change(params.expect(:instruction), user: Current.user)
    redirect_to @document, notice: "The agent is working on it. The suggestion appears here when it is ready."
  end
end
