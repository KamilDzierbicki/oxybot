class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many sign-in attempts from this network. Wait 3 minutes and try again." }
  # Guessing one account's password from many addresses is limited too
  rate_limit to: 10, within: 15.minutes, only: :create, by: -> { params[:email_address].to_s.strip.downcase },
             with: -> { redirect_to new_session_path, alert: "Too many sign-in attempts for this email. Wait 15 minutes and try again." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      # Rendered, not redirected, so the typed email stays in the form
      flash.now[:alert] = "Try another email address or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
