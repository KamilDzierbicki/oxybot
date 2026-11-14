# Sign-in by email: the visitor asks for a link, the link opens a page with one button, the button signs them in.
class Portal::SessionsController < Portal::BaseController
  rate_limit to: 5, within: 15.minutes, only: :create, by: -> { "#{params[:portal_slug]}:#{params[:email].to_s.strip.downcase}" },
             with: -> { redirect_to new_portal_session_path(portal_slug: params[:portal_slug]), alert: "Too many links asked for this email. Wait 15 minutes and try again." }
  rate_limit to: 20, within: 15.minutes, only: :create,
             with: -> { redirect_to new_portal_session_path(portal_slug: params[:portal_slug]), alert: "Too many sign-in requests from this network. Wait 15 minutes and try again." }

  def new
  end

  def create
    visitor = portal.portal_visitors.find_or_create_by(email: params[:email].to_s.strip.downcase)
    if visitor.persisted?
      PortalMailer.sign_in(visitor, visitor.generate_token_for(:sign_in)).deliver_later
      redirect_to new_portal_session_path(portal_slug: portal.portal_slug),
                  notice: "We sent a sign-in link to #{visitor.email}. It works once, for 20 minutes."
    else
      flash.now[:alert] = "Enter a valid email address."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @visitor = visitor_from_token
    redirect_to new_portal_session_path(portal_slug: portal.portal_slug), alert: expired_message unless @visitor
  end

  def update
    visitor = visitor_from_token
    return redirect_to(new_portal_session_path(portal_slug: portal.portal_slug), alert: expired_message) unless visitor

    visitor.update!(last_signed_in_at: Time.current) # invalidates the link
    sign_in(visitor)
    redirect_to portal_root, notice: "Signed in as #{visitor.email}."
  end

  def destroy
    sign_out
    redirect_to portal_root
  end

  private

  # Links are bound to the portal they were sent for
  def visitor_from_token
    visitor = PortalVisitor.find_by_token_for(:sign_in, params[:token].to_s)
    visitor if visitor&.account_id == portal.id
  end

  def expired_message = "This link has expired or was already used. Ask for a new one."
end
