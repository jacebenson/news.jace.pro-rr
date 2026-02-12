class ParticipantsController < ApplicationController
  def index
    @show_nav_tabs = true
    @participants = Participant.where.not(name: [ nil, "" ])

    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"
      @participants = @participants.where("name LIKE ? OR title LIKE ? OR company_name LIKE ?",
                                          search_term, search_term, search_term)
    end

    @participants = @participants.order(:name).page(params[:page]).per(48)
  end

  def show
    @show_nav_tabs = true
    @participant = Participant.find_by_slug(params[:name])

    unless @participant
      redirect_to items_path, alert: "Participant not found"
      return
    end

    @news_items = @participant.news_items
                              .where(active: true)
                              .includes(:news_feed)
                              .order(published_at: :desc)
                              .limit(12)

    @knowledge_sessions = @participant.knowledge_sessions
                                       .includes(:speakers)
                                       .order(created_at: :desc)
  end
end
