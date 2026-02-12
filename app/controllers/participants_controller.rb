class ParticipantsController < ApplicationController
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
