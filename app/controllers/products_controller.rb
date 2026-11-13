class ProductsController < ApplicationController
  before_action :set_product, only: %i[edit update]

  def index
    @products = Current.account.products.alphabetically
  end

  def new
    @product = Current.account.products.new
  end

  def create
    @product = Current.account.products.new(product_params)
    if @product.save
      redirect_to products_path, notice: "Product added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      redirect_to products_path, notice: "Product saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Current.account.products.find_by!(slug: params[:id])
  end

  def product_params
    params.expect(product: %i[name slug description])
  end
end
