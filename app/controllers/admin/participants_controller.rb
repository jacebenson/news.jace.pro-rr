module Admin
  class ParticipantsController < BaseController
    before_action :set_participant, only: %i[show edit update destroy]

    def index
      @participants = Participant.all

      if params[:search].present?
        @search = params[:search]
        @participants = @participants.where("name LIKE ? OR title LIKE ?", "%#{@search}%", "%#{@search}%")
      end

      @participants = @participants.order(:name).page(params[:page]).per(50)
    end

    def show
    end

    def new
      @participant = Participant.new
    end

    def edit
    end

    def create
      @participant = Participant.new(participant_params)
      if @participant.save
        redirect_to admin_participants_path, notice: "Participant created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @participant.update(participant_params)
        redirect_to admin_participants_path, notice: "Participant updated."
      else
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
  end
end
