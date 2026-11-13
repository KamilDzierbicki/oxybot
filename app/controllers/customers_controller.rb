class CustomersController < ApplicationController
  include Paginated
  def index
    @customers = paginate(Current.account.customers.by_arr)
  end

  # Forgets a customer: its contacts, its feedback notes and their insights
  def destroy
    customer = Current.account.customers.find(params[:id])
    Customer.transaction do
      customer.feedback_notes.destroy_all
      customer.insights.destroy_all
      Contact.where(customer: customer).delete_all
      customer.destroy!
    end
    redirect_to customers_path, notice: "#{customer.name} and their feedback were deleted."
  end

  def show
    @customer = Current.account.customers.find(params[:id])
    @insights = @customer.insights.includes(:product, :feature).latest_first
  end
end
