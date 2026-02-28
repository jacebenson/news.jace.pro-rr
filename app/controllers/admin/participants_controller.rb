module Admin
  class ParticipantsController < BaseController
    before_action :set_participant, only: %i[show edit update destroy merge compare]

    def index
      @participants = Participant.includes(:company, :mvp_awards)

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

    # GET /admin/participants/:id/merge
    # Step 1: Select target participant to merge into
    def merge
      @target = nil
      if params[:target_id].present?
        @target = Participant.find_by(id: params[:target_id])
        if @target.nil?
          flash.now[:alert] = "Target participant not found."
        elsif @target.id == @participant.id
          flash.now[:alert] = "Cannot merge a participant into itself."
          @target = nil
        end
      end
    end

    # GET /admin/participants/:id/compare/:target_id
    # Step 2: Compare and choose which fields to keep
    def compare
      @target = Participant.find(params[:target_id])

      if @target.id == @participant.id
        redirect_to merge_admin_participant_path(@participant), alert: "Cannot compare a participant with itself."
        return
      end

      @source_counts = @participant.related_counts
      @target_counts = @target.related_counts
    end

    # POST /admin/participants/:id/merge
    # Execute the merge with field choices
    def execute_merge
      @participant = Participant.find(params[:id])
      @target = Participant.find(params[:target_id])

      if @target.id == @participant.id
        redirect_to merge_admin_participant_path(@participant), alert: "Cannot merge a participant into itself."
        return
      end

      # Collect field choices from params
      field_choices = params[:fields] || {}

      begin
        source_name = @participant.name
        target_name = @target.name
        @target.merge!(@participant, field_choices)
        redirect_to admin_participant_path(@target), notice: "Successfully merged '#{source_name}' into '#{target_name}'."
      rescue => e
        redirect_to compare_admin_participant_path(@participant, @target), alert: "Merge failed: #{e.message}"
      end
    end

    # GET /admin/participants/duplicates
    # Show all potential duplicates for manual review
    def duplicates
      @duplicate_groups = Participant.find_potential_duplicates
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
