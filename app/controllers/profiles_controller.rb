class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(params.expect(user: %i[name custom_instructions]))
      redirect_to profile_path
    else
      render :show, status: :unprocessable_entity
    end
  end
end
