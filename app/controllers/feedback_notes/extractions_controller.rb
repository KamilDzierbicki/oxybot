# Runs extraction again, for example after the first product was added to a workspace
class FeedbackNotes::ExtractionsController < ApplicationController
  rate_limit to: 30, within: 1.minute, by: -> { Current.user.id }, with: -> { redirect_back_or_to feedback_notes_path, alert: "Slow down a little." }

  def create
    note = Current.account.feedback_notes.find(params[:feedback_note_id])
    note.reextract
    redirect_to note, notice: "Extracting insights again."
  end
end
