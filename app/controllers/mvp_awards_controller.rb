class MvpAwardsController < ApplicationController
  def index
    @show_nav_tabs = true

    # Base query: participants with MVP awards
    @participants = Participant.with_mvp_awards
                               .includes(:mvp_awards)
                               .where.not(name: [ nil, "" ])

    # Apply search filter
    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"
      @participants = @participants.where("name LIKE ? OR title LIKE ? OR company_name LIKE ?",
                                          search_term, search_term, search_term)
    end

    # Apply year filter
    if params[:year].present?
      @year = params[:year].to_i
      @participants = @participants.where(mvp_awards: { year: @year })
    end

    # Apply award type filter
    if params[:award_type].present?
      @award_type = params[:award_type]
      @participants = @participants.where(mvp_awards: { award_type: @award_type })
    end

    # Get available years and award types for filters
    @available_years = MvpAward.distinct.pluck(:year).sort.reverse
    @available_award_types = MvpAward::AWARD_TYPES

    # Build chart data based on current filters
    @chart_data = build_chart_data

    # Order and paginate
    @participants = @participants.order(:name).page(params[:page]).per(48)

    # Pre-calculate award counts and info for display
    @participants_with_awards = @participants.map do |participant|
      {
        participant: participant,
        award_count: participant.mvp_award_count,
        awards_by_year: participant.mvp_awards_by_year,
        award_types: participant.mvp_award_types
      }
    end
  end

  private

  def build_chart_data
    # Start with base query for awards
    awards = MvpAward.all

    # Apply same filters as participants
    if params[:search].present?
      participant_ids = Participant.where("name LIKE ?", "%#{sanitize_sql_like(params[:search])}%").pluck(:id)
      awards = awards.where(participant_id: participant_ids)
    end

    if params[:year].present?
      awards = awards.where(year: params[:year].to_i)
    end

    if params[:award_type].present?
      awards = awards.where(award_type: params[:award_type])
    end

    # Group by year and count
    data = awards.group(:year).count.sort.to_h

    {
      labels: data.keys,
      values: data.values,
      max_value: data.values.max || 0
    }
  end

  def sanitize_sql_like(string)
    return "" if string.blank?
    string.gsub(/[%_\\]/) { |match| "\\#{match}" }
  end
end
