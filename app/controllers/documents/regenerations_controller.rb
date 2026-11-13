class Documents::RegenerationsController < ApplicationController
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  include DocumentScoped

  def create
    @document.update!(status: "drafting")
    @document.generate_later
    redirect_to @document, notice: "Drafting again from the latest feedback. The current text stays in the version history."
  end
end
