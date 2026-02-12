module Admin
  class BackgroundJobsController < BaseController
    def index
      # Get job stats from Solid Queue tables
      @pending_jobs = SolidQueue::Job.where(finished_at: nil).count rescue 0
      @scheduled_jobs = SolidQueue::Job.where("scheduled_at > ?", Time.current).count rescue 0
      @failed_jobs = SolidQueue::FailedExecution.count rescue 0
      @recent_jobs = SolidQueue::Job.order(created_at: :desc).limit(20) rescue []

      # News item enrichment stats
      @items_pending_enrichment = NewsItem.where(state: "new").count rescue 0

      # Feed stats
      @active_feeds = NewsFeed.active.count
      @feeds_with_errors = NewsFeed.where.not(last_error: nil).count
      @recently_fetched = NewsFeed.where("last_successful_fetch > ?", 30.minutes.ago).count
      @never_fetched = NewsFeed.where(last_successful_fetch: nil).count

      # Partner stats
      @total_partners = Company.partners.count
      @partners_with_servicenow_content = Company.partners.where.not(servicenow_page_url: nil).count
      @partners_with_rss = Company.partners.where.not(rss_feed_url: nil).count
      @participants_without_company = Participant.where(company_id: nil).where.not(company_name: [ nil, "" ]).count

      # Get next scheduled run for each job type
      @next_runs = {}
      job_classes = %w[FetchNewsItemsJob FetchAppsJob EnrichItemJob FetchPartnersJob EnrichPartnersJob LinkParticipantsJob FetchSecFilingsJob BackupJob]
      job_classes.each do |job_class|
        next_job = SolidQueue::Job.where(class_name: job_class)
                                  .where(finished_at: nil)
                                  .where("scheduled_at > ?", Time.current)
                                  .order(:scheduled_at)
                                  .first rescue nil
        @next_runs[job_class] = next_job&.scheduled_at
      end
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

    def cancel_job
      job_class = params[:job_class]

      # Find and destroy all pending/scheduled jobs of this type
      jobs = SolidQueue::Job.where(class_name: job_class, finished_at: nil)
      count = jobs.count

      if count > 0
        # Also clean up any associated records
        job_ids = jobs.pluck(:id)
        SolidQueue::ScheduledExecution.where(job_id: job_ids).delete_all rescue nil
        SolidQueue::ReadyExecution.where(job_id: job_ids).delete_all rescue nil
        jobs.destroy_all
        flash[:notice] = "Cancelled #{count} #{job_class} job(s)"
      else
        flash[:alert] = "No pending #{job_class} jobs found"
      end

      redirect_to admin_background_jobs_path
    end

    def retry_failed
      count = SolidQueue::FailedExecution.count
      SolidQueue::FailedExecution.find_each do |failed|
        failed.retry rescue nil
      end
      flash[:notice] = "Retried #{count} failed job(s)"
      redirect_to admin_background_jobs_path
    end

    def clear_failed
      count = SolidQueue::FailedExecution.count
      SolidQueue::FailedExecution.delete_all
      flash[:notice] = "Cleared #{count} failed job(s)"
      redirect_to admin_background_jobs_path
    end
  end
end
