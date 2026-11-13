# Makes an old version the current text again. It is recorded as a new version, so the restore can be undone too.
class Documents::RestorationsController < ApplicationController
  include DocumentScoped

  def create
    version = @document.versions.find(params[:version_id])
    if version.body == @document.body
      redirect_to @document, notice: "That version is already the current text."
    else
      @document.edit(version.body, user: Current.user, summary: "Restored the version from #{version.created_at.to_fs(:short)}")
      redirect_to @document, notice: "Restored the version from #{version.created_at.to_fs(:short)}."
    end
  end
end
