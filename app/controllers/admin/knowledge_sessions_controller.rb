module Admin
  class KnowledgeSessionsController < BaseController
    before_action :set_session, only: %i[show edit update destroy]

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
    end

    def new
      @session = KnowledgeSession.new
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

    private

    def set_session
      @session = KnowledgeSession.find(params[:id])
    end

    def session_params
      params.require(:knowledge_session).permit(:title, :abstract, :code, :session_id,
                                                :event_id, :recording_url)
    end
  end
end
