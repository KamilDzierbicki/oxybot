class FeaturesController < ApplicationController
  include Paginated
  before_action :set_feature, only: %i[show edit update]

  def index
    @products = Current.account.products.alphabetically
    @product = Current.account.products.find_by(slug: params[:product]) if params[:product].present?
    features = Current.account.features.includes(:product).by_demand
    @features = paginate(@product ? features.where(product: @product) : features)
  end

  def show
    @insights = @feature.insights.includes(:customer, :feedback_note).latest_first
    @documents = @feature.documents.latest_first
  end

  def new
    @feature = Current.account.features.new(product: Current.account.products.find_by(slug: params[:product]))
  end

  def create
    @feature = Current.account.features.new(feature_params)
    if @feature.save
      redirect_to @feature
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @feature.update(feature_params)
      redirect_to @feature
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_feature
    @feature = Current.account.features.with_demand.find(params[:id])
  end

  def feature_params
    attributes = params.expect(feature: %i[title description status product_id])
    # The product id comes from a form: it must be one of this account's products
    attributes[:product_id] = Current.account.products.find(attributes[:product_id]).id if attributes[:product_id].present?
    attributes
  end
end
