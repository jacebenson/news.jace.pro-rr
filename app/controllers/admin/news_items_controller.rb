module Admin
  class NewsItemsController < BaseController
    before_action :set_news_item, only: %i[show edit update destroy]

    def index
      @news_items = NewsItem.includes(:news_feed)

      if params[:active].present?
        @news_items = @news_items.where(active: params[:active] == "true")
      end

      if params[:search].present?
        @search = params[:search]
        @news_items = @news_items.where("title LIKE ?", "%#{@search}%")
      end

      @news_items = @news_items.order(published_at: :desc).page(params[:page]).per(50)
    end

    def show
    end

    def new
      @news_item = NewsItem.new
    end

    def edit
    end

    def create
      @news_item = NewsItem.new(news_item_params)
      if @news_item.save
        redirect_to admin_news_items_path, notice: "Item created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @news_item.update(news_item_params)
        redirect_to admin_news_items_path, notice: "Item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @news_item.destroy
      redirect_to admin_news_items_path, notice: "Item deleted."
    end

    private

    def set_news_item
      @news_item = NewsItem.find(params[:id])
    end

    def news_item_params
      params.require(:news_item).permit(:title, :body, :url, :image_url, :active, :state,
                                        :item_type, :published_at, :news_feed_id)
    end
  end
end
