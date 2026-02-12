module Admin
  class CompaniesController < BaseController
    before_action :set_company, only: %i[show edit update destroy]

    def index
      @companies = Company.left_joins(:participants)
                          .select("companies.*, COUNT(participants.id) as participants_count")
                          .group("companies.id")

      if params[:is_partner].present?
        @companies = @companies.where(is_partner: true)
        @filter = "Partners"
      end

      if params[:is_customer].present?
        @companies = @companies.where(is_customer: true)
        @filter = "Customers"
      end

      if params[:search].present?
        @search = params[:search]
        @companies = @companies.where("companies.name LIKE ?", "%#{@search}%")
      end

      @companies = @companies.order("companies.name").page(params[:page]).per(50)
    end

    def show
      @participants = @company.participants.order(:name)
    end

    def new
      @company = Company.new
    end

    def edit
    end

    def create
      @company = Company.new(company_params)
      if @company.save
        redirect_to admin_companies_path, notice: "Company created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @company.update(company_params)
        redirect_to admin_companies_path, notice: "Company updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @company.destroy
      redirect_to admin_companies_path, notice: "Company deleted."
    end

    private

    def set_company
      @company = Company.find(params[:id])
    end

    def company_params
      params.require(:company).permit(:name, :active, :is_partner, :is_customer, :website,
                                      :image_url, :notes, :city, :state, :country,
                                      :partner_level, :build_level, :consulting_level)
    end
  end
end
