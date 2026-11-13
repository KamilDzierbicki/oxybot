class InvitationsMailer < ApplicationMailer
  def invite(invitation, token)
    @invitation = invitation
    @url = invitation_acceptance_url(token)
    mail to: invitation.email, subject: "#{invitation.invited_by.name} invited you to #{invitation.account.name} on OxyBot"
  end
end
