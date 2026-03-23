class MigrateParticipantImagesToS3Job < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50

  def perform
    unless S3Service.enabled?
      Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] S3 not enabled, skipping"
      return
    end

    Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] Starting batch"
    job_start = Time.current

    s3_host = ENV["S3_HOSTNAME"]

    # Find participants with non-S3 image URLs
    participants = Participant
      .where.not(image_url: [ nil, "" ])
      .where.not("image_url LIKE ?", "https://#{s3_host}%")
      .where.not("image_url LIKE ?", "/failed/%")  # Skip already-failed
      .limit(BATCH_SIZE)

    if participants.none?
      Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] No more participants to migrate - done!"
      return
    end

    Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] Processing #{participants.count} participants"

    processed = 0
    errors = 0

    participants.each do |participant|
      begin
        s3_url = upload_image_to_s3(participant)
        if s3_url
          participant.update_column(:image_url, s3_url)
          processed += 1
          Rails.logger.debug "[MIGRATE_PARTICIPANT_IMAGES] Migrated: #{participant.name}"
        else
          # Mark as failed so we don't retry forever
          participant.update_column(:image_url, "/failed/#{participant.image_url}")
          errors += 1
        end
      rescue StandardError => e
        errors += 1
        Rails.logger.warn "[MIGRATE_PARTICIPANT_IMAGES] Error for #{participant.name}: #{e.message}"
        participant.update_column(:image_url, "/failed/#{participant.image_url}") rescue nil
      end
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] Batch done: #{processed} uploaded, #{errors} failed in #{elapsed}s"

    # Check remaining and schedule next batch
    remaining = Participant
      .where.not(image_url: [ nil, "" ])
      .where.not("image_url LIKE ?", "https://#{s3_host}%")
      .where.not("image_url LIKE ?", "/failed/%")
      .count

    if remaining > 0
      Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] #{remaining} participants remaining, scheduling next batch"
      MigrateParticipantImagesToS3Job.set(wait: 2.seconds).perform_later
    else
      Rails.logger.info "[MIGRATE_PARTICIPANT_IMAGES] All participant images migrated!"
    end
  end

  private

  def upload_image_to_s3(participant)
    return nil if participant.image_url.blank?

    original_url = participant.image_url

    # Handle relative redwood URLs
    if original_url.start_with?("/")
      # These old redwood URLs won't work anymore, skip them
      Rails.logger.debug "[MIGRATE_PARTICIPANT_IMAGES] Skipping relative URL (no longer accessible): #{original_url}"
      return nil
    end

    # Determine file extension from URL or default to jpg
    ext = File.extname(URI.parse(original_url).path).presence || ".jpg"
    ext = ".jpg" unless %w[.jpg .jpeg .png .gif .webp].include?(ext.downcase)

    # Use slug if available, otherwise sanitize name
    filename = participant.slug.presence || participant.name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
    key = "participants/#{filename}#{ext}"

    S3Service.upload_from_url(url: original_url, key: key)
  rescue URI::InvalidURIError => e
    Rails.logger.debug "[MIGRATE_PARTICIPANT_IMAGES] Invalid URL for #{participant.name}: #{e.message}"
    nil
  end
end
