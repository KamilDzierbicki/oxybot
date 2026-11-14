# The customer portal: public pages of one workspace, for its customers. Staff sessions play no part here;
# a portal visitor is identified by a signed cookie set after they used a link sent to their email.
class Portal::BaseController < ApplicationController
  allow_unauthenticated_access
  layout "portal"

  before_action :set_portal
  helper_method :portal, :current_visitor

  private

  attr_reader :portal

  def set_portal
    @portal = Account.find_by!(portal_slug: params[:portal_slug].to_s.downcase, portal_enabled: true)
  end

  def current_visitor
    return @current_visitor if defined?(@current_visitor)

    visitor_id = cookies.signed[visitor_cookie]
    @current_visitor = visitor_id && portal.portal_visitors.includes(:portal_votes).find_by(id: visitor_id)
  end

  def require_visitor
    redirect_to new_portal_session_path(portal_slug: portal.portal_slug), alert: "Sign in with your email first." unless current_visitor
  end

  def sign_in(visitor)
    cookies.signed[visitor_cookie] = { value: visitor.id, expires: 30.days, httponly: true, same_site: :lax, secure: request.ssl? }
  end

  def sign_out
    cookies.delete(visitor_cookie)
  end

  def visitor_cookie = "portal_visitor_#{portal.id}"

  def portal_root = portal_root_path(portal_slug: portal.portal_slug)
end
