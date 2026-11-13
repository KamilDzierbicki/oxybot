class UsersController < ApplicationController
  admin_only

  def index
    @users = Current.account.users.alphabetically
    @invitations = Current.account.invitations.open.order(created_at: :desc)
  end

  def update
    user = Current.account.users.find(params[:id])
    attributes = params.expect(user: %i[role slack_user_id mattermost_user_id])
    %i[slack_user_id mattermost_user_id].each { |key| attributes[key] = attributes[key].presence if attributes.key?(key) }
    if user.update(attributes)
      redirect_to users_path
    else
      redirect_to users_path, alert: user.errors.full_messages.to_sentence
    end
  end

  def destroy
    user = Current.account.users.find(params[:id])
    return redirect_to(users_path, alert: "You cannot remove yourself.") if user == Current.user

    if user.destroy
      redirect_to users_path, notice: "#{user.name} was removed."
    else
      redirect_to users_path, alert: user.errors.full_messages.to_sentence
    end
  end
end
