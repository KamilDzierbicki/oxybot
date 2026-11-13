class InvitationsController < ApplicationController
  admin_only

  def create
    invitation = Current.account.invitations.new(params.expect(invitation: %i[email role]).merge(invited_by: Current.user))
    if invitation.save
      InvitationsMailer.invite(invitation, invitation.token).deliver_later
      # The link is also shown once, for teams without outgoing email set up yet
      flash[:invitation_url] = invitation_acceptance_url(invitation.token)
      redirect_to users_path, notice: "Invitation sent to #{invitation.email}."
    else
      redirect_to users_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.account.invitations.open.find(params[:id]).destroy!
    redirect_to users_path, notice: "Invitation withdrawn."
  end
end
