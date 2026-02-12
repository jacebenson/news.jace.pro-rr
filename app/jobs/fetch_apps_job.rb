class FetchAppsJob < ApplicationJob
  queue_as :default

  STORE_URL = "https://store.servicenow.com/sn_appstore_store.do"
  APP_API_URL = "https://store.servicenow.com/appStore.do"

  def perform
    Rails.logger.info "[APPS] Starting FetchAppsJob"
    job_start = Time.current

    begin
      # Step 1: Get the store page to extract auth token and cookies
      response = HTTParty.get(STORE_URL, timeout: 30, headers: user_agent_headers)

      unless response.success?
        Rails.logger.error "[APPS] Failed to fetch store page: #{response.code}"
        schedule_next_run
        return
      end

      # Extract g_ck token from script tags
      gck = extract_gck(response.body)
      unless gck
        Rails.logger.error "[APPS] Could not extract g_ck token"
        schedule_next_run
        return
      end

      cookies = extract_cookies(response)
      Rails.logger.info "[APPS] Got auth token and cookies"

      # Step 2: Fetch all apps listing
      apps_data = fetch_apps_listing(gck, cookies)
      unless apps_data
        Rails.logger.error "[APPS] Could not fetch apps listing"
        schedule_next_run
        return
      end

      Rails.logger.info "[APPS] Found #{apps_data.length} apps"

      # Step 3: Process each app (with delays to avoid rate limiting)
      processed = 0
      errors = 0

      apps_data.each_with_index do |app, index|
        # Rate limit: wait 1 second between requests
        sleep(1) if index > 0

        begin
          app_detail = fetch_app_detail(app, gck, cookies)
          if app_detail && save_app(app_detail)
            processed += 1
            Rails.logger.info "[APPS] #{index + 1}/#{apps_data.length} Processed: #{app['title']&.truncate(30)}"
          end
        rescue StandardError => e
          errors += 1
          Rails.logger.warn "[APPS] Error processing #{app['title']}: #{e.message}"
        end
      end

      elapsed = (Time.current - job_start).round(1)
      Rails.logger.info "[APPS] Done: #{processed} apps updated in #{elapsed}s (#{errors} errors)"

    rescue StandardError => e
      Rails.logger.error "[APPS] Fatal error: #{e.message}"
    end

    schedule_next_run
  end

  private

  def user_agent_headers
    {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }
  end

  def extract_gck(html)
    match = html.match(/var g_ck = ['"]([^'"]+)['"]/)
    match[1] if match
  end

  def extract_cookies(response)
    cookies = []
    if response.headers["set-cookie"]
      Array(response.headers["set-cookie"]).each do |cookie|
        cookies << cookie.split(";").first
      end
    end
    cookies.join("; ")
  end

  def fetch_apps_listing(gck, cookies)
    body = {
      sysparm_data: {
        action: "store.Search.GetLatestListing",
        searchParameters: {
          listingtype: [ "allintegrations", "ancillary_app", "certified_apps", "content", "industry_solution", "oem", "utility", "template" ],
          q: [ "" ],
          keyword: ""
        },
        orderBy: "recent",
        env_profile_sys_id: ""
      }.to_json
    }

    response = HTTParty.post(
      APP_API_URL,
      body: URI.encode_www_form(body),
      headers: {
        "X-Usertoken" => gck,
        "Cookie" => cookies,
        "Accept" => "application/json",
        "Content-Type" => "application/x-www-form-urlencoded"
      }.merge(user_agent_headers),
      timeout: 60
    )

    return nil unless response.success?

    data = JSON.parse(response.body)
    data["result"]
  rescue JSON::ParserError
    nil
  end

  def fetch_app_detail(app, gck, cookies)
    body = {
      sysparm_data: {
        action: "store.Application.GetById",
        application_id: app["source_app_id"],
        version: app["version"],
        isUpcomingIntegration: app["is_upcoming_integration"]
      }.to_json
    }

    response = HTTParty.post(
      APP_API_URL,
      body: URI.encode_www_form(body),
      headers: {
        "X-Usertoken" => gck,
        "Cookie" => cookies,
        "Accept" => "application/json",
        "Content-Type" => "application/x-www-form-urlencoded"
      }.merge(user_agent_headers),
      timeout: 30
    )

    return nil unless response.success?

    data = JSON.parse(response.body)
    data["result"]
  rescue JSON::ParserError
    nil
  end

  def save_app(app_data)
    return false if app_data["source_app_id"].blank?

    today = Date.current.to_s
    display_price = calculate_display_price(app_data)

    data = {
      last_fetched_at: Time.current,
      allow_for_existing_customers: app_data["allow_for_existing_customer"],
      allow_for_non_customers: app_data["allow_for_noncustomers"],
      allow_on_customer_subprod: app_data["allow_on_customer_subprod"],
      allow_on_developer_instance: app_data["allow_on_developer_instance"],
      allow_on_servicenow_instance: app_data["allow_on_sn_instance"],
      allow_trial: app_data["allow_trial"],
      allow_without_license: app_data["allow_without_license"],
      table_count: app_data["apprepo_custom_table_count"].to_i,
      company_logo: app_data["companyLogo"],
      company_name: app_data["company_name"],
      business_challenge: html_to_markdown(app_data["business_challenge"]),
      key_features: html_to_markdown(app_data["key_features"]),
      system_requirements: html_to_markdown(app_data["system_requirements"]),
      store_description: html_to_markdown(app_data["store_description"]),
      title: app_data["title"],
      logo: app_data["logo"],
      tagline: app_data["tagline"],
      purchase_count: app_data["purchaseCount"].to_i,
      review_count: app_data["total_reviews"].to_i,
      version: app_data["version"],
      supporting_media: app_data["supporting_media"].to_json,
      versions_data: app_data["versionsData"].to_json,
      support_links: app_data["support_link"].to_json,
      support_contacts: app_data["support_contact"].to_json,
      landing_page: app_data["landing_url"],
      app_type: app_data["application_type_label"],
      app_sub_type: app_data["application_sub_type_label"],
      source_app_id: app_data["source_app_id"],
      display_price: display_price
    }

    # Set published_at from versions data
    if app_data["versionsData"]&.first&.dig("publish_date")
      data[:published_at] = Time.parse(app_data["versionsData"].first["publish_date"]).to_i * 1000 rescue nil
    end

    existing = ServicenowStoreApp.find_by(source_app_id: app_data["source_app_id"])

    if existing
      # Update purchase trend
      trend = JSON.parse(existing.purchase_trend || "{}") rescue {}
      trend[today] = {
        count: app_data["purchaseCount"],
        price: display_price,
        version: app_data["version"]
      }
      data[:purchase_trend] = trend.to_json

      existing.update!(data)
    else
      # New app
      trend = { today => { count: app_data["purchaseCount"], price: display_price, version: app_data["version"] } }
      data[:purchase_trend] = trend.to_json
      ServicenowStoreApp.create!(data)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[APPS] Save failed: #{e.message}"
    false
  end

  def calculate_display_price(app_data)
    table_count = app_data["apprepo_custom_table_count"].to_i
    app_sub_type = app_data["application_sub_type_label"]

    if app_data["hide_buy"]
      "Request Price"
    elsif app_data["landing_url"].present?
      "Learn More"
    elsif app_data["price_type"] == "free" && table_count == 0
      "Free"
    elsif app_data["price_type"] == "free" && table_count > 0 && app_sub_type != "Integration"
      "Free-ish (consumes #{table_count} tables)"
    elsif app_data["price_type"] == "free" && table_count > 0 && app_sub_type == "Integration"
      "Free (integration tables[#{table_count}] not counted)"
    elsif app_data["price_type"] == "paid_per_month"
      "$#{app_data['price']} per month"
    elsif app_data["price_type"] == "custom" && app_data["custom_price_type"].present?
      "$#{app_data['price']}/mo #{app_data['custom_price_type']}"
    else
      "Unknown"
    end
  end

  def html_to_markdown(html)
    return nil if html.blank?
    ReverseMarkdown.convert(html, unknown_tags: :bypass)
  rescue
    html.gsub(/<[^>]+>/, "").strip
  end

  def schedule_next_run
    # Run again in 24 hours
    FetchAppsJob.set(wait: 24.hours).perform_later
  end
end
