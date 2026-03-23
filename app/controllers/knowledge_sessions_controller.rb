class KnowledgeSessionsController < ApplicationController
  before_action :set_event_path_helper

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

    # Search - includes title, abstract, code, and speaker names
    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"

      # Find session IDs that have matching speakers
      matching_speaker_session_ids = KnowledgeSessionParticipant
        .joins(:participant)
        .where("participants.name LIKE ?", search_term)
        .pluck(:knowledge_session_id)

      if matching_speaker_session_ids.any?
        sessions = sessions.where(
          "title LIKE ? OR abstract LIKE ? OR code LIKE ? OR knowledge_sessions.id IN (?)",
          search_term, search_term, search_term, matching_speaker_session_ids
        )
      else
        sessions = sessions.where("title LIKE ? OR abstract LIKE ? OR code LIKE ?",
                                  search_term, search_term, search_term)
      end
    end

    # Tags filter (for parties, etc.)
    if params[:tags].present?
      @tags = params[:tags]
      if @tags == "party"
        # Special handling for parties - look for PARTY code prefix
        sessions = sessions.where("code LIKE ?", "PARTY%")
      else
        safe_tags = sanitize_sql_like(@tags)
        tag_term = "%#{safe_tags}%"
        sessions = sessions.where("title LIKE ? OR abstract LIKE ?", tag_term, tag_term)
      end
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

    # Venue filter (Expo, Venetian, Wynn)
    if params[:venue].present?
      @venue_filter = params[:venue]
      sessions = sessions.where("times LIKE ?", "%#{sanitize_sql_like(@venue_filter)} -%")
    end

    # Room filter (specific room within venue)
    if params[:room].present?
      @room_filter = params[:room]
      sessions = sessions.where("times LIKE ?", "%\"room\":\"#{sanitize_sql_like(@room_filter)}\"%")
    end

    # Get all unique venues and rooms for filter dropdowns
    all_rooms = extract_rooms_from_sessions(KnowledgeSession.for_event(@event))
    @all_venues = all_rooms.map { |r| r.split(" - ").first }.uniq.sort
    @all_rooms = if @venue_filter.present?
      all_rooms.select { |r| r.start_with?("#{@venue_filter} -") }.sort
    else
      all_rooms.sort
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
    @stale_count = sessions.stale.count
    @active_count = @total_count - @stale_count

    # Sorting
    @sort = params[:sort].presence || "default"
    stale_threshold = 48.hours.ago

    sessions = case @sort
    when "updated"
      sessions.order(modified: :desc)
    when "alpha"
      sessions.order(:title_sort)
    when "time"
      # Sort by first event start date/time - need to extract from JSON
      sessions.order(
        Arel.sql("COALESCE(JSON_EXTRACT(times, '$[0].date'), '9999-99-99') ASC"),
        Arel.sql("COALESCE(JSON_EXTRACT(times, '$[0].startTimeFormatted'), '99:99') ASC")
      )
    else
      # Default: active sessions first (by modified desc), then stale sessions
      sessions.order(
        Arel.sql("CASE WHEN last_seen_at < '#{stale_threshold.iso8601}' THEN 1 ELSE 0 END"),
        modified: :desc
      )
    end

    # Pagination
    @per_page = params[:all] == "1" ? @total_count : 50
    @page = (params[:page] || 1).to_i
    @page = 1 if @page < 1
    @total_pages = (@total_count.to_f / @per_page).ceil
    @page = @total_pages if @page > @total_pages && @total_pages > 0

    @sessions = sessions.offset((@page - 1) * @per_page).limit(@per_page)
    @showing_all = params[:all] == "1"
  end

  def hide_speaker
    return head :forbidden unless admin?

    session = KnowledgeSession.find(params[:id])
    ksp = session.knowledge_session_participants.find_by(participant_id: params[:participant_id])

    if ksp
      ksp.update!(hidden: true)
      redirect_back fallback_location: k26_path, notice: "Speaker hidden from session."
    else
      redirect_back fallback_location: k26_path, alert: "Speaker not found."
    end
  end

  def unhide_speaker
    return head :forbidden unless admin?

    session = KnowledgeSession.find(params[:id])
    ksp = session.knowledge_session_participants.find_by(participant_id: params[:participant_id])

    if ksp
      ksp.update!(hidden: false)
      redirect_back fallback_location: k26_path, notice: "Speaker restored to session."
    else
      redirect_back fallback_location: k26_path, alert: "Speaker not found."
    end
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

  # Extract unique room names from sessions' times JSON
  def extract_rooms_from_sessions(sessions)
    sessions.where.not(times: [ nil, "", "[]" ]).pluck(:times).flat_map do |times_json|
      JSON.parse(times_json).map { |t| t["room"] }
    rescue JSON::ParserError
      []
    end.compact.uniq
  end

  def set_event_path_helper
    @event = params[:event] || "k26"
  end
end
