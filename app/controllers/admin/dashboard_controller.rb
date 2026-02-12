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

      @active_feeds = NewsFeed.where(active: true).count

      # System health
      @pending_jobs = SolidQueue::Job.where(finished_at: nil).count rescue 0
      @failed_jobs = SolidQueue::FailedExecution.count rescue 0
      @items_needing_enrichment = NewsItem.where(state: "new").count
      @feeds_with_errors = NewsFeed.where.not(last_error: nil).count
      @participants_unlinked = Participant.where(company_id: nil).count

      # Database size
      @db_size_mb = begin
        result = ActiveRecord::Base.connection.execute(
          "SELECT page_count * page_size / 1024.0 / 1024.0 as size_mb FROM pragma_page_count(), pragma_page_size()"
        )
        result.first["size_mb"].round(1)
      rescue
        "N/A"
      end
    end
  end
end
