class EnrichItemJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50

  def perform(item_id = nil)
    Rails.logger.info "[ENRICH] Starting EnrichItemJob"
    job_start = Time.current

    # Get items to enrich
    items = if item_id.present?
      NewsItem.where(id: item_id)
    else
      NewsItem.where(state: "new").order(created_at: :desc).limit(BATCH_SIZE)
    end

    if items.none?
      Rails.logger.info "[ENRICH] No items to enrich"
      return
    end

    Rails.logger.info "[ENRICH] Enriching #{items.count} items"

    processed = 0
    errors = 0

    items.find_each do |item|
      begin
        if enrich_item(item)
          processed += 1
        end
      rescue StandardError => e
        errors += 1
        Rails.logger.warn "[ENRICH] Error enriching #{item.id}: #{e.message}"
        item.update(state: "error")
      end
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[ENRICH] Done: #{processed} items in #{elapsed}s (#{errors} errors)"

    # If there are more items to process, queue another job
    remaining = NewsItem.where(state: "new").count
    if remaining > 0
      Rails.logger.info "[ENRICH] #{remaining} items remaining, scheduling next batch"
      EnrichItemJob.set(wait: 10.seconds).perform_later
    end
  end

  private

  def enrich_item(item)
    return false if item.url.blank?

    # Extract participants from body
    extract_participants(item) if item.body.present?

    # Try to fetch missing image
    fetch_og_image(item) if item.image_url.blank?

    # Mark as enriched
    item.update!(state: "enriched")
    true
  end

  def extract_participants(item)
    # Look for @mentions or known participant names in the body
    # This is a simplified version - could be enhanced with NLP
    return unless item.body.present?

    # Find participants whose names appear in the body
    Participant.where.not(name: [ nil, "" ]).find_each do |participant|
      next if participant.name.length < 3  # Skip very short names

      if item.body.downcase.include?(participant.name.downcase)
        unless item.participants.include?(participant)
          item.participants << participant rescue nil
        end
      end
    end
  end

  def fetch_og_image(item)
    return if item.url.blank?

    response = HTTParty.get(
      item.url,
      timeout: 15,
      headers: {
        "User-Agent" => "Mozilla/5.0 (compatible; NewsBot/1.0)"
      },
      follow_redirects: true
    )

    return unless response.success?

    # Look for og:image meta tag
    og_image = response.body.match(/<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/i)
    og_image ||= response.body.match(/<meta[^>]*content=["']([^"']+)["'][^>]*property=["']og:image["']/i)

    if og_image && og_image[1].present?
      item.update(image_url: og_image[1])
    end
  rescue StandardError => e
    Rails.logger.debug "[ENRICH] Failed to fetch OG image for #{item.id}: #{e.message}"
  end
end
