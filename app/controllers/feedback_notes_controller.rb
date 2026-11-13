class FeedbackNotesController < ApplicationController
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 30, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  def index
    @feedback_notes = Current.account.feedback_notes.includes(:customer, insights: :product).latest_first.limit(50)
  end

  def show
    @feedback_note = Current.account.feedback_notes.find(params[:id])
  end

  def new
    @feedback_note = Current.account.feedback_notes.new
  end

  def create
    @feedback_note = Current.account.feedback_notes.new(feedback_note_params.merge(source: "manual"))
    if @feedback_note.save
      redirect_to @feedback_note, notice: "Feedback saved. Insights appear in a few seconds."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_note_params
    params.expect(feedback_note: %i[body author author_email])
  end
end
