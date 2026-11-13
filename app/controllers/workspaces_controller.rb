# The workspace itself: export of all its data, and deletion
class WorkspacesController < ApplicationController
  admin_only

  def show
    @account = Current.account
  end

  # Deletes the account and everything in it; the name must be typed to confirm
  def destroy
    account = Current.account
    return redirect_to(workspace_path, alert: "Type the workspace name exactly to delete it.") unless params[:confirmation] == account.name

    terminate_session
    account.destroy!
    redirect_to new_session_path, notice: "The workspace #{account.name} and all its data were deleted."
  end
end
