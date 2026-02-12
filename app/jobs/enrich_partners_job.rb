class EnrichPartnersJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50
  DELAY_BETWEEN_BATCHES_MS = 200

  # Enriches partner companies with:
  # - Logo/image from og:image or twitter:image
  # - RSS feed URL discovery
  # - ServiceNow-related page URLs
  # - Products and services from sitemap analysis

  def perform
    Rails.logger.info "[ENRICH] Starting EnrichPartnersJob"
    job_start = Time.current

    total_count = Company.partners.active.count
    Rails.logger.info "[ENRICH] Found #{total_count} partners to analyze"

    processed = 0
    has_sitemap = 0
    has_servicenow_content = 0
    has_blog_content = 0
    discovered_feeds = 0
    errors = 0

    Company.partners.active.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      # Analyze batch in parallel using threads
      results = batch.map.with_index do |company, idx|
        Rails.logger.info "[ENRICH] Analyzing #{processed + idx + 1}/#{total_count} #{company.name}"
        analyze_partner(company)
      end

      # Batch update companies that have data
      updates = results.select { |r| r[:update_data]&.any? }
      if updates.any?
        Company.transaction do
          updates.each do |result|
            Company.find(result[:company_id]).update!(result[:update_data])
          end
        end
      end

      # Count results
      results.each do |result|
        processed += 1
        if result[:status] == :error
          errors += 1
        elsif result[:has_sitemap]
          has_sitemap += 1
          has_servicenow_content += 1 if result[:has_servicenow_content]
          has_blog_content += 1 if result[:has_blog_content]
          discovered_feeds += 1 if result[:discovered_feed]
        end
      end

      # Progress log every 100 partners
      if processed % 100 == 0
        Rails.logger.info "[ENRICH] Progress: #{processed}/#{total_count}"
      end

      # Delay between batches to be polite
      sleep(DELAY_BETWEEN_BATCHES_MS / 1000.0)
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[ENRICH] === Summary ==="
    Rails.logger.info "[ENRICH] Partners enriched: #{processed}"
    Rails.logger.info "[ENRICH] With sitemap.xml: #{has_sitemap} (#{(has_sitemap.to_f / processed * 100).round}%)"
    Rails.logger.info "[ENRICH] With ServiceNow content: #{has_servicenow_content}"
    Rails.logger.info "[ENRICH] With blog/news: #{has_blog_content}"
    Rails.logger.info "[ENRICH] RSS feeds discovered: #{discovered_feeds}"
    Rails.logger.info "[ENRICH] Errors: #{errors}"
    Rails.logger.info "[ENRICH] Completed in #{elapsed}s"

    # Schedule next run in 1 day
    schedule_next_run

    { processed: processed, has_sitemap: has_sitemap, has_servicenow_content: has_servicenow_content,
      has_blog_content: has_blog_content, discovered_feeds: discovered_feeds, errors: errors }
  end

  private

  def analyze_partner(company)
    partner_url = company.website
    return { company_id: company.id, status: :no_url } if partner_url.blank?

    # Normalize URL
    partner_url = "https://#{partner_url}" unless partner_url.start_with?("http")

    begin
      uri = URI.parse(partner_url)
      base_url = "#{uri.scheme}://#{uri.host}"
    rescue URI::InvalidURIError => e
      return { company_id: company.id, status: :error, error: e.message }
    end

    # Check for sitemap
    sitemap_url = "#{base_url}/sitemap.xml"
    analysis = analyze_sitemap(sitemap_url)

    if analysis[:error]
      return { company_id: company.id, status: :no_sitemap }
    end

    update_data = {}
    has_servicenow_content = false
    has_blog_content = false
    discovered_feed = nil

    # Discover logo
    logo_url = discover_logo(base_url)
    update_data[:image_url] = logo_url if logo_url.present?

    # Try to discover RSS feed if they have blog content
    if analysis[:blog_urls]&.any?
      has_blog_content = true
      first_blog_url = analysis[:blog_urls].first
      begin
        blog_path = URI.parse(first_blog_url).path.split("/")[0..-2].join("/")
        feed_url = discover_rss_feed(base_url, blog_path)
        if feed_url
          discovered_feed = feed_url
          update_data[:rss_feed_url] = feed_url
        end
      rescue URI::InvalidURIError
        # Ignore
      end
    end

    # Track partners with ServiceNow content
    if analysis[:servicenow_urls]&.any?
      has_servicenow_content = true

      # Pick the shortest (most likely landing page) ServiceNow URL
      best_url = analysis[:servicenow_urls].min_by(&:length)
      update_data[:servicenow_page_url] = best_url

      if analysis[:product_keywords]&.any?
        update_data[:products] = JSON.generate(analysis[:product_keywords])
      end

      if analysis[:service_keywords]&.any?
        update_data[:services] = JSON.generate(analysis[:service_keywords])
      end
    end

    # Update last sitemap check
    update_data[:last_sitemap_check] = Time.current
    update_data[:has_sitemap] = true

    {
      company_id: company.id,
      status: :ok,
      update_data: update_data,
      has_sitemap: true,
      has_servicenow_content: has_servicenow_content,
      has_blog_content: has_blog_content,
      discovered_feed: discovered_feed.present?
    }
  rescue => e
    { company_id: company.id, status: :error, error: e.message }
  end

  def discover_logo(base_url)
    response = HTTParty.get(
      base_url,
      timeout: 5,
      headers: { "User-Agent" => "ServiceNowNewsBot/1.0" },
      follow_redirects: true
    )

    if response.code != 200
      uri = URI.parse(base_url)
      return "https://www.google.com/s2/favicons?domain=#{uri.host}&sz=256"
    end

    html = response.body

    # Look for Open Graph image
    if html =~ /<meta\s+(?:property|name)=["']og:image["']\s+content=["']([^"']+)["']/i ||
       html =~ /<meta\s+content=["']([^"']+)["']\s+(?:property|name)=["']og:image["']/i
      logo_url = $1
      return normalize_url(logo_url, base_url)
    end

    # Look for twitter:image as alternative
    if html =~ /<meta\s+(?:property|name)=["']twitter:image["']\s+content=["']([^"']+)["']/i ||
       html =~ /<meta\s+content=["']([^"']+)["']\s+(?:property|name)=["']twitter:image["']/i
      logo_url = $1
      return normalize_url(logo_url, base_url)
    end

    # Fallback to Google favicon
    uri = URI.parse(base_url)
    "https://www.google.com/s2/favicons?domain=#{uri.host}&sz=256"
  rescue => e
    begin
      uri = URI.parse(base_url)
      "https://www.google.com/s2/favicons?domain=#{uri.host}&sz=256"
    rescue
      nil
    end
  end

  def normalize_url(url, base_url)
    if url.start_with?("/")
      "#{base_url}#{url}"
    elsif !url.start_with?("http")
      "#{base_url}/#{url}"
    else
      url
    end
  end

  def discover_rss_feed(base_url, blog_path)
    possible_feeds = [
      "#{base_url}#{blog_path}/feed",
      "#{base_url}#{blog_path}/rss",
      "#{base_url}#{blog_path}/feed.xml",
      "#{base_url}#{blog_path}/rss.xml",
      "#{base_url}/feed",
      "#{base_url}/rss",
      "#{base_url}/feed.xml",
      "#{base_url}/rss.xml"
    ]

    possible_feeds.each do |feed_url|
      begin
        response = HTTParty.head(
          feed_url,
          timeout: 3,
          headers: { "User-Agent" => "ServiceNowNewsBot/1.0" }
        )

        if response.code == 200
          content_type = response.headers["content-type"] || ""
          if content_type.include?("xml") || content_type.include?("rss") || content_type.include?("atom")
            return feed_url
          end
        end
      rescue
        # Continue to next attempt
      end
    end

    nil
  end

  def analyze_sitemap(url)
    response = HTTParty.get(
      url,
      timeout: 5,
      headers: { "User-Agent" => "ServiceNowNewsBot/1.0" },
      follow_redirects: true
    )

    return { error: "HTTP #{response.code}" } unless response.code == 200

    doc = Nokogiri::XML(response.body)

    analysis = {
      has_urls: false,
      url_count: 0,
      servicenow_urls: [],
      blog_urls: [],
      product_keywords: [],
      service_keywords: []
    }

    # Handle sitemap index - skip for now
    return analysis if doc.at_xpath("//sitemapindex")

    # Check if it's a regular sitemap
    urls = doc.xpath("//url/loc").map(&:text)
    return analysis if urls.empty?

    analysis[:has_urls] = true
    analysis[:url_count] = urls.length

    # Find ServiceNow-related content (limit to 10)
    analysis[:servicenow_urls] = urls.select { |u|
      u.match?(/servicenow|snow|service-now/i)
    }.first(10)

    # Find blog/news content (limit to 5)
    analysis[:blog_urls] = urls.select { |u|
      u.match?(/\/(blog|insights|resources|news)\//i)
    }.first(5)

    # Detect products from ServiceNow URLs
    product_patterns = [
      /\/products?\//i,
      /\/apps?\//i,
      /\/solutions?\//i,
      /\/integrations?\//i,
      /store\.servicenow\.com/i
    ]

    bad_product_words = %w[index html php asp page default home]

    analysis[:servicenow_urls].each do |url|
      if product_patterns.any? { |p| url.match?(p) }
        parts = url.split("/")
        product_slug = parts.last.presence || parts[-2]
        next unless product_slug

        # Clean up the slug
        product_slug = product_slug
          .sub(/\.html?$/i, "")
          .sub(/\.php$/i, "")
          .sub(/\?.*$/, "")
          .gsub("-", " ")
          .strip

        # Filter out bad/generic names
        if product_slug.length > 2 && !bad_product_words.include?(product_slug.downcase)
          analysis[:product_keywords] << product_slug
        end
      end
    end

    # Detect services
    service_patterns = [
      /consulting/i,
      /implementation/i,
      /advisory/i,
      /professional-services/i,
      /training/i,
      /support/i
    ]

    analysis[:servicenow_urls].each do |url|
      service_patterns.each do |pattern|
        if url.match?(pattern)
          match = url.match(pattern)
          analysis[:service_keywords] << match[0].downcase if match
        end
      end
    end

    # Deduplicate
    analysis[:product_keywords].uniq!
    analysis[:service_keywords].uniq!

    analysis
  rescue => e
    { error: e.message }
  end

  def schedule_next_run
    # Run again in 1 day
    EnrichPartnersJob.set(wait: 1.day).perform_later
  end
end
