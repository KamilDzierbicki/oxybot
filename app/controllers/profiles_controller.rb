class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    Current.user.update!(params.expect(user: %i[name slack_user_id custom_instructions]))
    redirect_to profile_path, notice: "Profile saved."
  end
end
