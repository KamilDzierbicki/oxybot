class Invitations::AcceptancesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_invitation

  def show; end

  def create
    @user = @invitation.accept(**params.expect(user: %i[name password]).to_h.symbolize_keys)
    if @user&.persisted?
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to #{@invitation.account.name}."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_invitation
    @invitation = Invitation.find_open_by_token(params[:token])
    render plain: "This invitation has expired or was already used.", status: :not_found unless @invitation
  end
end
