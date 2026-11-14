# A support or sales tool whose conversations become feedback notes (Intercom, Zendesk, Gong). Each sync imports
# what is new since the last one; the note keeps the item's id in the source, so nothing is imported twice, and
# extraction and triage then run as for any other feedback.
module Integration::FeedbackSource
  extend ActiveSupport::Concern

  FIRST_SYNC = 30.days

  def feedback_source? = true

  def sync
    since = synced_at || FIRST_SYNC.ago
    started = Time.current
    imported = client.feedback_since(since).count { |item| import(item) }
    update!(synced_at: started)
    imported
  end

  private

  # item: { external_id:, body:, author_email:, author:, created_at: }
  def import(item)
    return false if item[:body].to_s.strip.blank?

    note = account.feedback_notes.create_with(body: item[:body].to_s.strip.first(20_000), author: item[:author], author_email: item[:author_email],
                                              created_at: item[:created_at] || Time.current)
                  .find_or_create_by!(source: kind, external_id: item[:external_id].to_s)
    note.previously_new_record?
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
