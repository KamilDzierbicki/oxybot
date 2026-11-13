class ApplicationController < ActionController::Base
  include Authentication
  include AdminOnly

  # Dates and times show in the account's time zone (AI settings), not the server's
  around_action :use_account_time_zone

  private

  def use_account_time_zone(&action)
    Time.use_zone(Current.account&.time_zone.presence || "UTC", &action)
  end

  public
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
