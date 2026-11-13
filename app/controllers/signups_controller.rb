class SignupsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_signup_path, alert: "Try again later." }

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(params.expect(signup: %i[account_name name email_address password]))
    if @signup.save
      start_new_session_for @signup.user
      redirect_to integrations_path, notice: "Welcome to OxyBot. Connect your tools to start collecting feedback."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
