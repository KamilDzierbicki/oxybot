class Documents::SuggestionsController < ApplicationController
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 10, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  include DocumentScoped

  def create
    @document.request_change(params.expect(:instruction), user: Current.user)
    redirect_to @document, notice: "The agent is working on it. The suggestion appears here when it is ready."
  end
end
