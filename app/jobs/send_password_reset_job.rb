class SendPasswordResetJob < ApplicationJob
  queue_as :default

  def perform(email_address)
    user = User.find_by(email_address: email_address.strip.downcase)
    PasswordsMailer.reset(user).deliver_now if user
  end
end
