class Documents::RegenerationsController < ApplicationController
  include DocumentScoped

  def create
    @document.update!(status: "drafting")
    @document.generate_later
    redirect_to @document, notice: "Drafting again from the latest feedback. The current text stays in the version history."
  end
end
