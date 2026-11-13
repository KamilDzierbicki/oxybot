class Features::SpecsController < ApplicationController
  include FeatureScoped

  def create
    redirect_to Document.draft(account: Current.account, kind: "prd", creator: Current.user, feature: @feature)
  end
end
