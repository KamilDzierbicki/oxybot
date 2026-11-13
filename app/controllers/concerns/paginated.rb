# Lists show PER_PAGE rows with older/newer links, so a large workspace never renders thousands of rows
module Paginated
  extend ActiveSupport::Concern

  PER_PAGE = 50

  included do
    helper_method :page_number
  end

  private

  def page_number
    [ params[:page].to_i, 1 ].max
  end

  def paginate(scope)
    @total_count = scope.unscope(:order, :select).count
    scope.offset((page_number - 1) * PER_PAGE).limit(PER_PAGE)
  end
end
