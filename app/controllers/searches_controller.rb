# One search box for the whole workspace. Full-text only, so searching never calls a model.
class SearchesController < ApplicationController
  LIMIT = 8

  def show
    @query = params[:q].to_s.strip.first(200)
    return if @query.length < 2

    pattern = "%#{Current.account.class.sanitize_sql_like(@query)}%"
    @insights = Current.account.insights.includes(:customer, :product).keyword_search(@query, limit: LIMIT)
    @features = Current.account.features.with_demand.includes(:product).keyword_search(@query, limit: LIMIT)
    @documents = Current.account.documents.where("title ILIKE ?", pattern).latest_first.limit(LIMIT)
    @feedback_notes = Current.account.feedback_notes.where("body ILIKE ?", pattern).latest_first.limit(LIMIT)
    @customers = Current.account.customers.where("name ILIKE ?", pattern).by_arr.limit(LIMIT)
  end
end
