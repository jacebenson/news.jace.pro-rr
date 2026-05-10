module Admin
  class KnowledgeSessionsController < BaseController
    before_action :set_session, only: %i[show edit update destroy remove_speaker]

    def index
      @sessions = KnowledgeSession.all

      if params[:event].present?
        @sessions = @sessions.for_event(params[:event])
        @filter = params[:event].upcase
      end

      if params[:search].present?
        @search = params[:search]
        safe_search = sanitize_sql_like(@search)
        @sessions = @sessions.where("title LIKE ? OR code LIKE ?", "%#{safe_search}%", "%#{safe_search}%")
      end

      @sessions = @sessions.order(:title_sort).page(params[:page]).per(50)
    end

    def show
      @speakers = @session.speakers.order(:name)
    end

    def new
      @session = KnowledgeSession.new
      # Pre-select event if passed in params
      if params[:event].present?
        @session.event_id = KnowledgeSession::EVENT_IDS[params[:event].to_sym]
      end
    end

    def edit
    end

    def create
      @session = KnowledgeSession.new(session_params)
      if @session.save
        redirect_to admin_knowledge_sessions_path, notice: "Session created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @session.update(session_params)
        redirect_to admin_knowledge_sessions_path, notice: "Session updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @session.destroy
      redirect_to admin_knowledge_sessions_path, notice: "Session deleted."
    end

    def remove_speaker
      ksp = @session.knowledge_session_participants.find_by(participant_id: params[:participant_id])
      if ksp
        participant_name = ksp.participant.name
        ksp.destroy
        redirect_to admin_knowledge_session_path(@session), notice: "Removed #{participant_name} from session."
      else
        redirect_to admin_knowledge_session_path(@session), alert: "Speaker not found."
      end
    end

    def mark_canceled
      @session.update!(canceled_at: Time.current)
      redirect_back fallback_location: admin_knowledge_session_path(@session), notice: "Session marked as canceled."
    end

    def unmark_canceled
      @session.update!(canceled_at: nil)
      redirect_back fallback_location: admin_knowledge_session_path(@session), notice: "Session restored (no longer marked as canceled)."
    end

    private

    def set_session
      @session = KnowledgeSession.find(params[:id])
    end

    def session_params
      params.require(:knowledge_session).permit(:title, :abstract, :code, :session_id,
                                                :event_id, :recording_url, :url, :times, :last_seen_at)
    end
  end
end
