module Admin
  class ParticipantsController < BaseController
    before_action :set_participant, only: %i[show edit update destroy]

    def index
      @participants = Participant.includes(:company)

      # Count for filter badges
      @unlinked_count = Participant.where(company_id: nil).where.not(company_name: [ nil, "" ]).count

      if params[:filter] == "unlinked"
        @participants = @participants.where(company_id: nil).where.not(company_name: [ nil, "" ])
      end

      if params[:search].present?
        @search = params[:search]
        safe_search = sanitize_sql_like(@search)
        @participants = @participants.where("name LIKE ? OR title LIKE ? OR company_name LIKE ?", "%#{safe_search}%", "%#{safe_search}%", "%#{safe_search}%")
      end

      @participants = @participants.order(:name).page(params[:page]).per(50)
    end

    def show
    end

    def new
      @participant = Participant.new
      @companies = Company.order(:name).pluck(:name, :id)
    end

    def edit
      @companies = Company.order(:name).pluck(:name, :id)
    end

    def create
      @participant = Participant.new(participant_params)
      if @participant.save
        redirect_to admin_participants_path, notice: "Participant created."
      else
        @companies = Company.order(:name).pluck(:name, :id)
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @participant.update(participant_params)
        redirect_to redirect_path, notice: "Participant updated."
      else
        @companies = Company.order(:name).pluck(:name, :id)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @participant.destroy
      redirect_to admin_participants_path, notice: "Participant deleted."
    end

    private

    def set_participant
      @participant = Participant.find(params[:id])
    end

    def participant_params
      params.require(:participant).permit(:name, :title, :bio, :image_url, :linkedin_url,
                                          :company_name, :company_id, :user_id)
    end

    def redirect_path
      if params[:return_to].present?
        params[:return_to]
      else
        admin_participants_path
      end
    end
  end
end
