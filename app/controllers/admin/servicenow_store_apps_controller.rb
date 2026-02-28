module Admin
  class ServicenowStoreAppsController < BaseController
    before_action :set_app, only: %i[show edit update destroy refresh]

    def index
      @apps = ServicenowStoreApp.all

      if params[:search].present?
        @search = params[:search]
        safe_search = sanitize_sql_like(@search)
        @apps = @apps.where("title LIKE ? OR company_name LIKE ?", "%#{safe_search}%", "%#{safe_search}%")
      end

      @apps = @apps.order(purchase_count: :desc).page(params[:page]).per(50)
    end

    def show
    end

    def new
      @app = ServicenowStoreApp.new
    end

    def edit
    end

    def create
      @app = ServicenowStoreApp.new(app_params)
      if @app.save
        redirect_to admin_store_apps_path, notice: "App created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @app.update(app_params)
        redirect_to admin_store_apps_path, notice: "App updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @app.destroy
      redirect_to admin_store_apps_path, notice: "App deleted."
    end

    def refresh
      FetchAppsJob.perform_later(@app.id)
      redirect_to edit_admin_store_app_path(@app), notice: "Refresh job started. Check back in a minute."
    end

    private

    def set_app
      @app = ServicenowStoreApp.find(params[:id])
    end

    def app_params
      params.require(:servicenow_store_app).permit(:title, :tagline, :store_description,
                                                   :company_name, :logo, :app_type, :landing_page,
                                                   :source_app_id, :listing_id, :purchase_count,
                                                   :review_count, :display_price, :featured_icon)
    end
  end
end
