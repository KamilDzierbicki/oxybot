module FeatureScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_feature
  end

  private

  def set_feature
    @feature = Current.account.features.find(params[:feature_id])
  end
end
