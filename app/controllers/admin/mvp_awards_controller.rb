class Admin::MvpAwardsController < Admin::BaseController
  before_action :set_participant
  before_action :set_mvp_award, only: [ :edit, :update, :destroy ]

  def new
    @mvp_award = @participant.mvp_awards.build
  end

  def create
    @mvp_award = @participant.mvp_awards.build(mvp_award_params)

    if @mvp_award.save
      redirect_to edit_admin_participant_path(@participant), notice: "MVP Award added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @mvp_award.update(mvp_award_params)
      redirect_to edit_admin_participant_path(@participant), notice: "MVP Award updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mvp_award.destroy
    redirect_to edit_admin_participant_path(@participant), notice: "MVP Award removed successfully."
  end

  private

  def set_participant
    @participant = Participant.find(params[:participant_id])
  end

  def set_mvp_award
    @mvp_award = @participant.mvp_awards.find(params[:id])
  end

  def mvp_award_params
    params.require(:mvp_award).permit(:year, :award_type, :source_url)
  end
end
