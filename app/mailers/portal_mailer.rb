class PortalMailer < ApplicationMailer
  def sign_in(visitor, token)
    @visitor = visitor
    @url = portal_sign_in_url(portal_slug: visitor.account.portal_slug, token: token)
    mail subject: "Your sign-in link for #{visitor.account.name}", to: visitor.email
  end
end
