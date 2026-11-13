class Documents::RejectionsController < ApplicationController
  include DocumentScoped

  def create
    @document.suggestions.find(params[:suggestion_id]).reject
    redirect_to @document
  end
end
