class Features::LaunchReviewsController < ApplicationController
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  include FeatureScoped

  def create
    redirect_to Document.draft(account: Current.account, kind: "launch_review", creator: Current.user, feature: @feature)
  end
end
