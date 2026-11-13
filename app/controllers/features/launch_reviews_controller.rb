class Features::LaunchReviewsController < ApplicationController
  include FeatureScoped

  def create
    redirect_to Document.draft(account: Current.account, kind: "launch_review", creator: Current.user, feature: @feature)
  end
end
