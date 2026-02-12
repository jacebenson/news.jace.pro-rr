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

      # S3 Migration Status
      @s3_stats = calculate_s3_stats

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

    def trigger_s3_migration
      # Check if job is already running
      migration_running = SolidQueue::Job
        .where(class_name: "MigrateImagesToS3Job")
        .where(finished_at: nil)
        .exists? rescue false

      if migration_running
        redirect_to admin_dashboard_path, alert: "S3 migration job is already running"
      elsif !S3Service.enabled?
        redirect_to admin_dashboard_path, alert: "S3 is not configured"
      else
        MigrateImagesToS3Job.perform_later
        redirect_to admin_dashboard_path, notice: "S3 migration job started"
      end
    end

    private

    def calculate_s3_stats
      return nil unless S3Service.enabled?

      s3_host = ENV["S3_HOSTNAME"]
      total_with_images = NewsItem.where.not(image_url: [ nil, "" ]).count

      migrated = NewsItem.where("image_url LIKE ?", "https://#{s3_host}%").count
      failed = NewsItem.where("image_url LIKE ?", "/failed/%").count
      pending = NewsItem
        .where.not(image_url: [ nil, "" ])
        .where.not("image_url LIKE ?", "https://#{s3_host}%")
        .where.not("image_url LIKE ?", "/failed/%")
        .where.not("image_url LIKE ?", "/%")
        .count

      # Check if migration job is currently running
      @s3_migration_running = SolidQueue::Job
        .where(class_name: "MigrateImagesToS3Job")
        .where(finished_at: nil)
        .exists? rescue false

      percentage = total_with_images > 0 ? ((migrated.to_f / total_with_images) * 100).round(1) : 0

      {
        total_with_images: total_with_images,
        migrated: migrated,
        failed: failed,
        pending: pending,
        percentage: percentage,
        running: @s3_migration_running
      }
    end
  end
end
