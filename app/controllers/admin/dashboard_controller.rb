module Admin
  class DashboardController < BaseController
    def index
      @stats = {
        users: User.count,
        news_feeds: NewsFeed.count,
        news_items: NewsItem.count,
        participants: Participant.count,
        companies: Company.count,
        knowledge_sessions: KnowledgeSession.count,
        store_apps: ServicenowStoreApp.count
      }

      @recent_news = NewsItem.order(created_at: :desc).limit(5)
      @active_feeds = NewsFeed.where(active: true).count
    end
  end
end
