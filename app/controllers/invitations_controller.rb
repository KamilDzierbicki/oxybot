class InvitationsController < ApplicationController
  admin_only

  def create
    attributes = params.expect(invitation: %i[email role])
    # Inviting the same address again replaces the open invitation, so there is one live link per person
    Current.account.invitations.open.where(email: attributes[:email].to_s.strip.downcase).destroy_all
    invitation = Current.account.invitations.new(attributes.merge(invited_by: Current.user))
    if invitation.save
      InvitationsMailer.invite(invitation, invitation.token).deliver_later
      # The link is also shown once, for teams without outgoing email set up yet
      flash[:invitation_url] = invitation_acceptance_url(token: invitation.token)
      redirect_to users_path, notice: "Invitation sent to #{invitation.email}."
    else
      # Re-render with the typed email and the error next to the form
      @invitation = invitation
      @users = Current.account.users.alphabetically
      @invitations = Current.account.invitations.open.order(created_at: :desc)
      render "users/index", status: :unprocessable_entity
    end
  end

  def destroy
    Current.account.invitations.open.find(params[:id]).destroy!
    redirect_to users_path
  end
end
