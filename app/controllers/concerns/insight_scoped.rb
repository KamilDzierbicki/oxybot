module InsightScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_insight
  end

  private

  def set_insight
    @insight = Current.account.insights.find(params[:insight_id])
  end

  # The triage list removes the row in place and says what happened, with an undo; other pages reload
  def respond_with_triaged(notice)
    undo = insight_restoration_path(@insight)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [ turbo_stream.remove(@insight),
                               turbo_stream.update("flash", partial: "shared/flash_message", locals: { type: "notice", text: notice, undo: undo }) ]
      end
      format.html { redirect_back_or_to insights_path, notice: notice, flash: { undo: undo } }
    end
  end
end
