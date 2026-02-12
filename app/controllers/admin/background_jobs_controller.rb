module Admin
  class BackgroundJobsController < BaseController
    def index
      # Get job stats from Solid Queue tables
      @pending_jobs = SolidQueue::Job.where(finished_at: nil).count rescue 0
      @scheduled_jobs = SolidQueue::Job.where("scheduled_at > ?", Time.current).count rescue 0
      @failed_jobs = SolidQueue::FailedExecution.count rescue 0
      @recent_jobs = SolidQueue::Job.order(created_at: :desc).limit(20) rescue []

      # News item enrichment stats
      @items_pending_enrichment = NewsItem.where(state: nil).or(NewsItem.where(state: "pending")).count rescue 0

      # Feed stats (last_successful_fetch is stored as ms timestamp)
      thirty_minutes_ago_ms = (Time.current.to_f * 1000 - 30 * 60 * 1000).to_i
      @active_feeds = NewsFeed.active.count
      @feeds_with_errors = NewsFeed.where("error_count > 0").count
      @recently_fetched = NewsFeed.where("last_successful_fetch > ?", thirty_minutes_ago_ms).count
      @never_fetched = NewsFeed.where(last_successful_fetch: nil).count

      # Partner stats
      @total_partners = Company.partners.count
      @partners_with_servicenow_content = Company.partners.where.not(servicenow_page_url: nil).count
      @partners_with_rss = Company.partners.where.not(rss_feed_url: nil).count
      @participants_without_company = Participant.where(company_id: nil).where.not(company_name: [ nil, "" ]).count
    end

    def run_job
      job_name = params[:job]

      case job_name
      when "fetch_news_items"
        FetchNewsItemsJob.perform_later
        flash[:notice] = "FetchNewsItemsJob enqueued"
      when "fetch_apps"
        FetchAppsJob.perform_later
        flash[:notice] = "FetchAppsJob enqueued"
      when "enrich_items"
        EnrichItemJob.perform_later
        flash[:notice] = "EnrichItemJob enqueued"
      when "fetch_partners"
        FetchPartnersJob.perform_later
        flash[:notice] = "FetchPartnersJob enqueued"
      when "enrich_partners"
        EnrichPartnersJob.perform_later
        flash[:notice] = "EnrichPartnersJob enqueued"
      when "link_participants"
        LinkParticipantsJob.perform_later
        flash[:notice] = "LinkParticipantsJob enqueued"
      when "fetch_sec_filings"
        FetchSecFilingsJob.perform_later
        flash[:notice] = "FetchSecFilingsJob enqueued"
      when "backup"
        BackupJob.perform_later(force: true)
        flash[:notice] = "BackupJob enqueued (forced)"
      else
        flash[:alert] = "Unknown job: #{job_name}"
      end

      redirect_to admin_background_jobs_path
    end
  end
end
