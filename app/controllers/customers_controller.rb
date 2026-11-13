class CustomersController < ApplicationController
  def index
    @customers = Current.account.customers.by_arr
  end

  def show
    @customer = Current.account.customers.find(params[:id])
    @insights = @customer.insights.includes(:product, :feature).latest_first
  end
end
