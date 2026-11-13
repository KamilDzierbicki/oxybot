# Daily cleanup of data nobody needs any more: ended sessions (IP and browser), invitations that expired or were
# used a month ago, and routed chat messages older than the retention period (CHAT_RETENTION_DAYS, default 90).
class PurgeExpiredDataJob < ApplicationJob
  queue_as :default

  def perform
    Session.expired.delete_all
    Invitation.where(expires_at: ...1.month.ago).or(Invitation.where(accepted_at: ...1.month.ago)).delete_all
    ChatMessage.where(created_at: ...ENV.fetch("CHAT_RETENTION_DAYS", 90).to_i.days.ago).where.not(processed_at: nil).delete_all
  end
end
