class KnowledgeSessionsController < ApplicationController
  def index
    @show_nav_tabs = true
    @event = params[:event] || "k26"
    @event_name = event_name(@event)

    sessions = KnowledgeSession.for_event(@event).includes(:speakers)

    # User's saved list - supports "mine" or a user ID for sharing
    if params[:list].present?
      list_user = if params[:list] == "mine" && logged_in?
        current_user
      elsif params[:list] =~ /^\d+$/
        User.find_by(id: params[:list])
      end

      if list_user
        session_ids = list_user.knowledge_session_lists
                               .joins(:knowledge_session)
                               .where(knowledge_sessions: { event_id: event_id_for(@event) })
                               .pluck(:knowledge_session_id)
        sessions = sessions.where(id: session_ids)
        @showing_list = true
        @list_owner = list_user
        @shareable_url = url_for(controller: "knowledge_sessions", action: "index", event: @event, list: list_user.id, only_path: false) unless params[:list] == list_user.id.to_s
      else
        # Invalid list parameter - show empty or redirect
        sessions = sessions.none if params[:list] != "mine"
        @showing_list = true
      end
    end

    # Search
    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"
      sessions = sessions.where("title LIKE ? OR abstract LIKE ? OR code LIKE ?",
                                search_term, search_term, search_term)
    end

    # Tags filter (for parties, etc.)
    if params[:tags].present?
      @tags = params[:tags]
      safe_tags = sanitize_sql_like(@tags)
      tag_term = "%#{safe_tags}%"
      sessions = sessions.where("title LIKE ? OR abstract LIKE ?", tag_term, tag_term)
    end

    # Company filter - filter sessions by speaker's company
    if params[:company].present?
      @company_filter = params[:company]
      safe_company = sanitize_sql_like(@company_filter)
      company_term = "%#{safe_company}%"
      session_ids_with_company = KnowledgeSessionParticipant
        .joins(:participant)
        .where("participants.company_name LIKE ?", company_term)
        .pluck(:knowledge_session_id)
      sessions = sessions.where(id: session_ids_with_company)
    end

    # Exclude ServiceNow-only sessions
    if params[:exclude_servicenow] == "1"
      @exclude_servicenow = true
      # Find sessions where ALL speakers are from ServiceNow
      servicenow_only_ids = find_servicenow_only_session_ids(sessions)
      sessions = sessions.where.not(id: servicenow_only_ids) if servicenow_only_ids.any?
    end

    # Get all unique companies for the filter dropdown (before pagination)
    @all_companies = Participant
      .joins(:knowledge_session_participants)
      .joins("INNER JOIN knowledge_sessions ON knowledge_sessions.id = knowledge_session_participants.knowledge_session_id")
      .where(knowledge_sessions: { event_id: event_id_for(@event) })
      .where.not(company_name: [ nil, "" ])
      .distinct
      .pluck(:company_name)
      .sort

    @total_count = sessions.count
    @sessions = sessions.order(:title_sort, :title).page(params[:page]).per(50)
  end

  private

  def event_name(event)
    case event
    when "k20" then "Knowledge 2020"
    when "k21" then "Knowledge 2021"
    when "k22" then "Knowledge 2022"
    when "k23" then "Knowledge 2023"
    when "k24" then "Knowledge 2024"
    when "k25" then "Knowledge 2025"
    when "k26" then "Knowledge 2026"
    when "nulledge25" then "nullEDGE 2025"
    else event.upcase
    end
  end

  def event_id_for(event)
    KnowledgeSession::EVENT_IDS[event.to_sym]
  end

  # Find sessions where ALL speakers are from ServiceNow
  def find_servicenow_only_session_ids(sessions)
    session_ids = sessions.pluck(:id)
    return [] if session_ids.empty?

    # Get sessions that have at least one non-ServiceNow speaker
    sessions_with_non_sn = KnowledgeSessionParticipant
      .joins(:participant)
      .where(knowledge_session_id: session_ids)
      .where.not("LOWER(participants.company_name) LIKE ?", "%servicenow%")
      .pluck(:knowledge_session_id)
      .uniq

    # Sessions with speakers
    sessions_with_speakers = KnowledgeSessionParticipant
      .where(knowledge_session_id: session_ids)
      .pluck(:knowledge_session_id)
      .uniq

    # ServiceNow-only = has speakers but no non-ServiceNow speakers
    sessions_with_speakers - sessions_with_non_sn
  end
end
