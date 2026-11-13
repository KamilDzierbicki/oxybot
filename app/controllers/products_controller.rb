class ProductsController < ApplicationController
  include Paginated
  before_action :set_product, only: %i[edit update]

  def index
    @products = paginate(Current.account.products.alphabetically)
  end

  def new
    @product = Current.account.products.new
  end

  def create
    @product = Current.account.products.new(product_params)
    if save_unique(@product)
      redirect_to products_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      redirect_to products_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def save_unique(product)
    product.save
  rescue ActiveRecord::RecordNotUnique
    product.errors.add(:slug, "is already taken")
    false
  end

  def set_product
    @product = Current.account.products.find_by!(slug: params[:id])
  end

  def product_params
    params.expect(product: %i[name slug description])
  end
end
