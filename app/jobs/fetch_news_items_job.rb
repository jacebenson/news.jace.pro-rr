class FetchNewsItemsJob < ApplicationJob
  queue_as :default

  CONCURRENCY = 5
  SKIP_IF_FETCHED_WITHIN_MINUTES = 30

  def perform(feed_id = nil)
    Rails.logger.info "[FETCH] Starting FetchNewsItemsJob"
    job_start = Time.current

    # Build query for feeds to process
    feeds = NewsFeed.where(active: true).where.not(status: "dead")
    feeds = feeds.where(id: feed_id) if feed_id.present?

    # Skip recently fetched feeds unless specific feed requested
    unless feed_id.present?
      cutoff_ms = (SKIP_IF_FETCHED_WITHIN_MINUTES.minutes.ago.to_f * 1000).to_i
      before_count = feeds.count
      feeds = feeds.where("last_successful_fetch IS NULL OR last_successful_fetch < ?", cutoff_ms)
      skipped = before_count - feeds.count
      Rails.logger.info "[FETCH] Skipping #{skipped} recently fetched feeds" if skipped > 0
    end

    if feeds.none?
      Rails.logger.info "[FETCH] No feeds to process"
      schedule_next_run(feed_id)
      return
    end

    # Process feeds
    total_found = 0
    total_processed = 0
    errors = 0

    Rails.logger.info "[FETCH] Processing #{feeds.count} feeds"

    feeds.find_each do |feed|
      result = process_feed(feed)
      if result[:error]
        errors += 1
        Rails.logger.warn "[FETCH] #{feed.id} #{feed.title.truncate(20)} ERROR: #{result[:error].truncate(50)}"
      else
        total_found += result[:found] || 0
        total_processed += result[:processed] || 0
        Rails.logger.info "[FETCH] #{feed.id} #{feed.title.truncate(20)} #{result[:found]} -> #{result[:processed]}"
      end
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[FETCH] Done: #{total_processed} items from #{feeds.count} feeds in #{elapsed}s (#{errors} errors)"

    # Queue enrichment job for new items
    EnrichItemJob.perform_later if total_processed > 0

    # Schedule next run
    schedule_next_run(feed_id)
  end

  private

  def process_feed(feed)
    case feed.feed_type
    when "rss"
      process_rss_feed(feed)
    when "scrape"
      process_scrape_feed(feed)
    when "youtube search"
      process_youtube_feed(feed)
    else
      { error: "Unknown feed type: #{feed.feed_type}" }
    end
  rescue StandardError => e
    feed.update(
      last_error: e.message,
      error_count: (feed.error_count || 0) + 1
    )
    { error: e.message }
  end

  def process_rss_feed(feed)
    url = feed.fetch_url.presence || feed.url
    return { error: "No URL" } if url.blank?

    response = HTTParty.get(url, timeout: 30, headers: {
      "User-Agent" => "Mozilla/5.0 (compatible; NewsBot/1.0)"
    })

    return { error: "HTTP #{response.code}" } unless response.success?

    parsed = Feedjira.parse(response.body)
    return { error: "Could not parse feed" } unless parsed

    items = parsed.entries || []
    processed = 0

    items.each do |item|
      next if item.url.blank? || item.url.start_with?("/")

      news_item_data = {
        title: item.title&.strip,
        url: item.url,
        news_feed_id: feed.id,
        item_type: determine_type(item),
        published_at: parse_date(item.published || item.updated),
        body: extract_body(item),
        image_url: extract_image(item),
        active: true,
        state: "new"
      }

      if create_or_update_news_item(news_item_data)
        processed += 1
      end
    end

    feed.update(
      last_successful_fetch: (Time.current.to_f * 1000).to_i,
      error_count: 0,
      last_error: nil
    )

    { found: items.length, processed: processed }
  end

  def process_scrape_feed(feed)
    # Simplified scrape - just log for now
    Rails.logger.info "[FETCH] Scrape feeds not yet implemented"
    { found: 0, processed: 0 }
  end

  def process_youtube_feed(feed)
    # YouTube search feeds not yet implemented
    Rails.logger.info "[FETCH] YouTube search feeds not yet implemented"
    { found: 0, processed: 0 }
  end

  def create_or_update_news_item(data)
    return false if data[:url].blank?

    existing = NewsItem.find_by(url: data[:url])
    if existing
      # Only update if there's new content
      return false
    end

    NewsItem.create!(data)
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.debug "[FETCH] Skip invalid: #{e.message}"
    false
  end

  def determine_type(item)
    url = item.url.to_s.downcase
    return "video" if url.include?("youtube.com") || url.include?("youtu.be")
    return "podcast" if item.respond_to?(:itunes_duration) && item.itunes_duration.present?
    "article"
  end

  def extract_body(item)
    raw = item.content || item.summary || item.description
    return nil if raw.blank?
    ReverseMarkdown.convert(raw, unknown_tags: :bypass)
  rescue
    raw&.gsub(/<[^>]+>/, "")&.strip
  end

  def extract_image(item)
    # Try various common image sources
    if item.respond_to?(:image) && item.image.present?
      return item.image
    end
    if item.respond_to?(:enclosure_url) && item.enclosure_url.present?
      return item.enclosure_url if item.enclosure_type&.start_with?("image")
    end
    if item.respond_to?(:media_content) && item.media_content.present?
      return item.media_content.first[:url] rescue nil
    end
    nil
  end

  def parse_date(date)
    return Time.current.to_i * 1000 if date.blank?

    time = case date
    when Time, DateTime
      date.to_time
    when String
      Time.parse(date) rescue Time.current
    else
      Time.current
    end

    (time.to_f * 1000).to_i
  end

  def schedule_next_run(feed_id)
    # Run again in 1 hour
    FetchNewsItemsJob.set(wait: 1.hour).perform_later(feed_id)
  end
end
