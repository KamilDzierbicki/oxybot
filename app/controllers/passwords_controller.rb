class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }
  rate_limit to: 3, within: 15.minutes, only: :create, by: -> { params[:email_address].to_s.strip.downcase },
             with: -> { redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)." }

  def new
  end

  # The lookup and the mail happen in a job, so the answer takes the same time whether the address exists or not
  def create
    SendPasswordResetJob.perform_later(params[:email_address].to_s)
    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.reset_password(params.permit(:password, :password_confirmation))
      redirect_to new_session_path, notice: "Password has been reset."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private
    # The token travels as a query parameter (filtered from logs), not in the path
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
