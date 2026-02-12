class MigrateImagesToS3Job < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform
    unless S3Service.enabled?
      Rails.logger.info "[MIGRATE_IMAGES] S3 not enabled, skipping"
      return
    end

    Rails.logger.info "[MIGRATE_IMAGES] Starting batch"
    job_start = Time.current

    # Find items with external image URLs (not already on S3, not blank, not local)
    s3_host = ENV["S3_HOSTNAME"]
    items = NewsItem
      .where.not(image_url: [ nil, "" ])
      .where.not("image_url LIKE ?", "https://#{s3_host}%")
      .where.not("image_url LIKE ?", "/%")  # Skip local paths
      .limit(BATCH_SIZE)

    if items.none?
      Rails.logger.info "[MIGRATE_IMAGES] No more items to migrate - done!"
      return
    end

    Rails.logger.info "[MIGRATE_IMAGES] Processing #{items.count} items"

    processed = 0
    errors = 0

    items.each do |item|
      begin
        s3_url = upload_image_to_s3(item)
        if s3_url
          item.update_column(:image_url, s3_url)
          processed += 1
        else
          # Mark as failed so we don't retry forever - prefix with /failed/
          item.update_column(:image_url, "/failed/#{item.image_url}")
          errors += 1
        end
      rescue StandardError => e
        errors += 1
        Rails.logger.warn "[MIGRATE_IMAGES] Error for #{item.id}: #{e.message}"
        # Mark as failed
        item.update_column(:image_url, "/failed/#{item.image_url}") rescue nil
      end
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[MIGRATE_IMAGES] Batch done: #{processed} uploaded, #{errors} failed in #{elapsed}s"

    # Check remaining and schedule next batch
    remaining = NewsItem
      .where.not(image_url: [ nil, "" ])
      .where.not("image_url LIKE ?", "https://#{s3_host}%")
      .where.not("image_url LIKE ?", "/%")
      .count

    if remaining > 0
      Rails.logger.info "[MIGRATE_IMAGES] #{remaining} items remaining, scheduling next batch"
      MigrateImagesToS3Job.set(wait: 2.seconds).perform_later
    else
      Rails.logger.info "[MIGRATE_IMAGES] All images migrated!"
    end
  end

  private

  def upload_image_to_s3(item)
    return nil if item.image_url.blank?

    # Determine file extension from URL or default to jpg
    ext = File.extname(URI.parse(item.image_url).path).presence || ".jpg"
    ext = ".jpg" unless %w[.jpg .jpeg .png .gif .webp].include?(ext.downcase)

    key = "news-items/#{item.id}#{ext}"

    S3Service.upload_from_url(url: item.image_url, key: key)
  rescue URI::InvalidURIError => e
    Rails.logger.debug "[MIGRATE_IMAGES] Invalid URL for #{item.id}: #{e.message}"
    nil
  end
end
