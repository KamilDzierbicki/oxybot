class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "OxyBot <oxybot@localhost>")
  layout "mailer"
end
