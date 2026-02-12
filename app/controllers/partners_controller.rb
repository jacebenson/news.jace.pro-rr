class PartnersController < ApplicationController
  def index
    @show_nav_tabs = true
    partners = Company.where(is_partner: true, active: true)

    # Filter by partner level
    if params[:level].present?
      @level = params[:level]
      partners = partners.where(partner_level: @level)
    end

    # Filter by build level
    if params[:build].present?
      @build = params[:build]
      partners = partners.where(build_level: @build)
    end

    # Filter by consulting level
    if params[:consulting].present?
      @consulting = params[:consulting]
      partners = partners.where(consulting_level: @consulting)
    end

    # Filter by country
    if params[:country].present?
      @country = params[:country]
      partners = partners.where(country: @country)
    end

    # Filter by state
    if params[:state].present?
      @state_filter = params[:state]
      partners = partners.where(state: @state_filter)
    end

    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"
      partners = partners.where(
        "name LIKE ? OR notes LIKE ? OR city LIKE ? OR state LIKE ? OR country LIKE ?",
        search_term, search_term, search_term, search_term, search_term
      )
    end

    # Filter by has people
    if params[:has_people] == "true"
      @has_people = true
      partners = partners.joins(:participants).distinct
    end

    # Get filter options for the UI
    @partner_levels = Company.partners.active.where.not(partner_level: [ nil, "" ]).distinct.pluck(:partner_level).compact.sort
    @build_levels = Company.partners.active.where.not(build_level: [ nil, "" ]).distinct.pluck(:build_level).compact.sort
    @consulting_levels = Company.partners.active.where.not(consulting_level: [ nil, "" ]).distinct.pluck(:consulting_level).compact.sort
    @countries = Company.partners.active.where.not(country: [ nil, "" ]).distinct.pluck(:country).compact.sort
    @states = Company.partners.active.where.not(state: [ nil, "" ]).distinct.pluck(:state).compact.sort

    @partners = partners.includes(:participants).order(:name).page(params[:page]).per(50)
  end

  def show
    @show_nav_tabs = true
    @partner = Company.find(params[:id])

    # Redirect to partners index if not a partner or inactive
    unless @partner.is_partner && @partner.active
      redirect_to partners_path, alert: "Partner not found"
      return
    end

    @participants = @partner.participants.order(:name)
  end
end
