class Admin::StartupFoundersController < Admin::BaseController
  before_action :set_participant

  def new
    @startup_founder = @participant.startup_founders.build
  end

  def create
    @startup_founder = @participant.startup_founders.build(startup_founder_params)

    if @startup_founder.save
      redirect_to edit_admin_participant_path(@participant), notice: "Startup founder record added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @startup_founder = @participant.startup_founders.find(params[:id])
    @startup_founder.destroy
    redirect_to edit_admin_participant_path(@participant), notice: "Startup founder record removed successfully."
  end

  private

  def set_participant
    @participant = Participant.find(params[:participant_id])
  end

  def startup_founder_params
    params.require(:startup_founder).permit(:company_name, :source_url)
  end
end
