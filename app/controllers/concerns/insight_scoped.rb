module InsightScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_insight
  end

  private

  def set_insight
    @insight = Current.account.insights.find(params[:insight_id])
  end

  # The inbox removes the triaged row in place; other pages reload
  def respond_with_triaged(notice)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@insight) }
      format.html { redirect_back_or_to insights_path, notice: notice }
    end
  end
end
