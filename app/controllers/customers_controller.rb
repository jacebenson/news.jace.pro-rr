class CustomersController < ApplicationController
  def index
    @show_nav_tabs = true
    customers = Company.where(is_customer: true, active: true)

    if params[:search].present?
      @search = params[:search]
      search_term = "%#{@search}%"
      customers = customers.where(
        "name LIKE ? OR notes LIKE ? OR city LIKE ? OR state LIKE ? OR country LIKE ?",
        search_term, search_term, search_term, search_term, search_term
      )
    end

    @customers = customers.order(:name).page(params[:page]).per(50)
  end
end
