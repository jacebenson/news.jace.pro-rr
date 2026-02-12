module Admin
  class NewsFeedsController < BaseController
    before_action :set_news_feed, only: %i[show edit update destroy]

    def index
      @news_feeds = NewsFeed.all

      if params[:active].present?
        @news_feeds = @news_feeds.where(active: params[:active] == "true")
      end

      if params[:search].present?
        @search = params[:search]
        @news_feeds = @news_feeds.where("title LIKE ? OR url LIKE ?", "%#{@search}%", "%#{@search}%")
      end

      @news_feeds = @news_feeds.order(:title).page(params[:page]).per(50)
    end

    def show
    end

    def new
      @news_feed = NewsFeed.new
    end

    def edit
    end

    def create
      @news_feed = NewsFeed.new(news_feed_params)
      if @news_feed.save
        redirect_to admin_news_feeds_path, notice: "Feed created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @news_feed.update(news_feed_params)
        redirect_to admin_news_feeds_path, notice: "Feed updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @news_feed.destroy
      redirect_to admin_news_feeds_path, notice: "Feed deleted."
    end

    private

    def set_news_feed
      @news_feed = NewsFeed.find(params[:id])
    end

    def news_feed_params
      params.require(:news_feed).permit(:title, :active, :status, :notes, :image_url,
                                        :url, :default_author, :feed_type, :fetch_url)
    end
  end
end
