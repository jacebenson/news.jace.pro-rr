class ApplicationsController < ApplicationController
  def index
    @show_nav_tabs = true
    apps = ServicenowStoreApp.all

    if params[:search].present?
      @search = params[:search]
      search_term = "%#{@search}%"
      apps = apps.where("title LIKE ? OR tagline LIKE ? OR store_description LIKE ?",
                        search_term, search_term, search_term)
    end

    if params[:company].present?
      @company = params[:company]
      apps = apps.where("company_name LIKE ?", "%#{@company}%")
    end

    @apps = apps.order(purchase_count: :desc).page(params[:page]).per(50)
  end

  def show
    @show_nav_tabs = true
    @app = ServicenowStoreApp.find(params[:id])

    # Parse JSON fields
    @purchase_history = parse_json(@app.purchase_trend)
    @versions = parse_json(@app.versions_data)
    @supporting_media = parse_json(@app.supporting_media)
    @support_links = parse_json(@app.support_links)
    @support_contacts = parse_json(@app.support_contacts)
  end

  private

  def parse_json(data)
    return {} if data.blank?
    JSON.parse(data)
  rescue JSON::ParserError
    {}
  end
end
