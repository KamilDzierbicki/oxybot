class Documents::VersionsController < ApplicationController
  include DocumentScoped

  def index
    @versions = @document.versions.includes(:user).reverse
  end

  def show
    @version = @document.versions.find(params[:id])
    @diff = Document::Diff.new(@version.previous&.body || "", @version.body)
  end
end
