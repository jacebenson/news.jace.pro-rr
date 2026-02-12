class NewsItemsController < ApplicationController
  def index
    @show_nav_tabs = true
    items = NewsItem.where(active: true).includes(:news_feed, :participants)

    # Filter by participant slug
    if params[:participant].present?
      participant = Participant.find_by_slug(params[:participant])
      if participant
        @participant = participant
        items = items.joins(:news_item_participants)
                     .where(news_item_participants: { participant_id: participant.id })
      end
    end

    # Search - check title, body, url, and participant names
    if params[:search].present?
      @search = params[:search]
      safe_search = sanitize_sql_like(@search)
      search_term = "%#{safe_search}%"

      # Find participant IDs matching the search
      matching_participant_ids = Participant.where("name LIKE ?", search_term).pluck(:id)

      if matching_participant_ids.any?
        # Search in title, body, url, OR has a matching participant
        items = items.left_joins(:news_item_participants)
                     .where("news_items.title LIKE ? OR news_items.body LIKE ? OR news_items.url LIKE ? OR news_item_participants.participant_id IN (?)",
                            search_term, search_term, search_term, matching_participant_ids)
                     .distinct
      else
        items = items.where("title LIKE ? OR body LIKE ? OR url LIKE ?", search_term, search_term, search_term)
      end
    end

    @news_items = items.order(published_at: :desc).page(params[:page]).per(25)
  end

  def show
    @show_nav_tabs = true
    @item = NewsItem.includes(:news_feed, :participants).find(params[:id])
  end
end
