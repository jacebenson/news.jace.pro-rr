class ApplicationsController < ApplicationController
  def index
    @show_nav_tabs = true
    apps = ServicenowStoreApp.all

    # Search filter (title, tagline, store_description)
    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"
      apps = apps.where("title LIKE ? OR tagline LIKE ? OR store_description LIKE ?",
                        search_term, search_term, search_term)
    end

    # Company filter
    if params[:company].present?
      @company = params[:company]
      safe_company = sanitize_sql_like(@company)
      apps = apps.where("company_name LIKE ?", "%#{safe_company}%")
    end

    # App type filter
    if params[:app_type].present?
      @app_type = params[:app_type]
      apps = apps.where(app_type: @app_type)
    end

    # Price filter (Free vs Paid)
    if params[:price].present?
      @price = params[:price]
      apps = case @price
      when "free" then apps.where("display_price LIKE ? OR display_price = ?", "%Free%", "")
      when "paid" then apps.where("display_price NOT LIKE ? AND display_price != ?", "%Free%", "")
      else apps
      end
    end

    # Trial available filter
    if params[:trial] == "1"
      @trial = true
      apps = apps.where(allow_trial: true)
    end

    # No license required filter
    if params[:no_license] == "1"
      @no_license = true
      apps = apps.where(allow_without_license: true)
    end

    # Instance availability filters
    if params[:dev_instance] == "1"
      @dev_instance = true
      apps = apps.where(allow_on_developer_instance: true)
    end

    if params[:prod_instance] == "1"
      @prod_instance = true
      apps = apps.where(allow_on_servicenow_instance: true)
    end

    # Minimum reviews filter
    if params[:min_reviews].present?
      @min_reviews = params[:min_reviews].to_i
      apps = apps.where("review_count >= ?", @min_reviews)
    end

    # Recently published filter
    if params[:published_within].present?
      @published_within = params[:published_within].to_i
      apps = apps.where("published_at >= ?", @published_within.days.ago)
    end

    # Sorting
    @sort = params[:sort] || "popular"
    @direction = params[:direction] || "desc"

    sort_column = case @sort
    when "title" then "title"
    when "company" then "company_name"
    when "published" then "published_at"
    when "updated" then "updated_at"
    when "reviews" then "review_count"
    when "tables" then "table_count"
    when "installs" then "purchase_count"
    else "purchase_count" # default to popular
    end

    sort_direction = @direction == "asc" ? :asc : :desc
    apps = apps.order(sort_column => sort_direction)

    @apps = apps.page(params[:page]).per(50)
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
