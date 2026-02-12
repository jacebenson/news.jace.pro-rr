module Admin
  class ServicenowInvestmentsController < BaseController
    before_action :set_investment, only: %i[show edit update destroy]

    def index
      @investments = ServicenowInvestment.all

      if params[:search].present?
        @search = params[:search]
        safe_search = sanitize_sql_like(@search)
        @investments = @investments.where("company_name LIKE ? OR summary LIKE ?", "%#{safe_search}%", "%#{safe_search}%")
      end

      @investments = @investments.order(date: :desc).page(params[:page]).per(50)
    end

    def show
    end

    def new
      @investment = ServicenowInvestment.new
    end

    def edit
    end

    def create
      @investment = ServicenowInvestment.new(investment_params)
      if @investment.save
        redirect_to admin_investments_path, notice: "Investment created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @investment.update(investment_params)
        redirect_to admin_investments_path, notice: "Investment updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @investment.destroy
      redirect_to admin_investments_path, notice: "Investment deleted."
    end

    private

    def set_investment
      @investment = ServicenowInvestment.find(params[:id])
    end

    def investment_params
      params.require(:servicenow_investment).permit(:investment_type, :content, :summary, :url,
                                                    :amount, :currency, :date, :company_name)
    end
  end
end
