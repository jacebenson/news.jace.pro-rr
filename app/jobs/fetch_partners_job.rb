class FetchPartnersJob < ApplicationJob
  queue_as :default

  # Fetch partners from ServiceNow Partner Portal API
  # Creates or updates Company records with partner data

  def perform
    Rails.logger.info "[PARTNERS] Starting FetchPartnersJob"
    job_start = Time.current

    # Get cookie and token from Partner Portal
    token, cookie = get_cookie_and_token
    unless token && cookie
      Rails.logger.error "[PARTNERS] Failed to get authentication token/cookie"
      schedule_next_run
      return { error: "Failed to get token/cookie" }
    end

    # Fetch partner list
    partners = fetch_partner_list(token, cookie)
    if partners.empty?
      Rails.logger.error "[PARTNERS] No partners found"
      schedule_next_run
      return { error: "No partners found" }
    end

    Rails.logger.info "[PARTNERS] Processing #{partners.length} partners..."

    created = 0
    updated = 0
    errors = 0
    website_matches = 0

    partners.each_with_index do |partner, idx|
      begin
        result = process_partner(partner)
        case result[:action]
        when :created then created += 1
        when :updated then updated += 1
        end
        website_matches += 1 if result[:match_type] == :website

        if result[:match_type] == :website
          Rails.logger.info "[PARTNERS] Website match: \"#{partner[:name]}\" -> \"#{result[:matched_as]}\""
        end
      rescue => e
        errors += 1
        Rails.logger.warn "[PARTNERS] Error processing #{partner[:name]}: #{e.message}" if errors <= 5
      end

      if (idx + 1) % 500 == 0
        Rails.logger.info "[PARTNERS] Progress: #{idx + 1}/#{partners.length}"
      end
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[PARTNERS] Done: #{created} created, #{updated} updated, #{errors} errors in #{elapsed}s"
    Rails.logger.info "[PARTNERS] Website domain matches: #{website_matches}"

    # Schedule next run in 1 day
    schedule_next_run

    { processed: partners.length, created: created, updated: updated, errors: errors, website_matches: website_matches }
  end

  private

  def get_cookie_and_token
    Rails.logger.info "[PARTNERS] Getting cookie and token..."

    response = HTTParty.get(
      "https://partnerportal.service-now.com/partnerhome?id=partnerlist",
      headers: { "User-Agent" => "Mozilla/5.0 (compatible; NewsBot/1.0)" },
      timeout: 30,
      follow_redirects: true
    )

    return [ nil, nil ] unless response.success?

    html = response.body
    token = nil

    # Extract g_ck token from script tags
    if html =~ /window\.g_ck\s*=\s*'([^']+)'/
      token = $1
    end

    # Extract cookies
    cookies = response.headers.get_fields("set-cookie") || []
    cookie = cookies.map { |c| c.split(";").first }.join("; ")

    Rails.logger.info "[PARTNERS] Got token: #{token ? 'yes' : 'no'}, cookie: #{cookie.present? ? 'yes' : 'no'}"
    [ token, cookie ]
  end

  def fetch_partner_list(token, cookie)
    Rails.logger.info "[PARTNERS] Fetching partner list..."

    response = HTTParty.post(
      "https://partnerportal.service-now.com/xmlhttp.do",
      headers: {
        "X-UserToken" => token,
        "Cookie" => cookie,
        "Content-Type" => "application/x-www-form-urlencoded"
      },
      body: {
        sysparm_processor: "displayPartnersAjaxUtils",
        sysparm_name: "getPartners"
      },
      timeout: 60
    )

    unless response.success?
      Rails.logger.error "[PARTNERS] HTTP error: #{response.code}"
      return []
    end

    Rails.logger.info "[PARTNERS] Received #{response.body.length} bytes"
    parse_partner_xml(response.body)
  end

  def parse_partner_xml(xml_data)
    doc = Nokogiri::XML(xml_data)
    answer = doc.at_xpath("//xml")&.attr("answer")
    return [] unless answer

    # Decode HTML entities
    decoded = CGI.unescapeHTML(answer)
    partners = JSON.parse(decoded)

    Rails.logger.info "[PARTNERS] Found #{partners.length} partners"

    partners.map do |partner|
      segment_program_map = begin
        JSON.parse(partner["segmentProgramMap"] || "{}")
      rescue
        {}
      end

      {
        name: partner["name"],
        website: partner["url"],
        build_level: segment_program_map["Build"],
        consulting_level: segment_program_map["Consulting & Implementation"],
        reseller_level: segment_program_map["Reseller"],
        service_provider_level: segment_program_map["Service Provider"],
        partner_level: partner["partnerTiers"]&.gsub("<br>", ""),
        city: partner["city"],
        state: partner["state"],
        country: partner["country"],
        servicenow_url: partner["pfUrl"]
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[PARTNERS] JSON parse error: #{e.message}"
    []
  rescue => e
    Rails.logger.error "[PARTNERS] Parse error: #{e.message}"
    []
  end

  def process_partner(partner)
    existing, match_type = find_existing_company(partner)
    now = Time.current

    if existing
      update_data = {
        is_partner: true,
        last_fetched_at: now,
        last_found_in_partner_list: now,
        # Always update partner levels from Partner Portal
        build_level: partner[:build_level],
        consulting_level: partner[:consulting_level],
        reseller_level: partner[:reseller_level],
        service_provider_level: partner[:service_provider_level],
        partner_level: partner[:partner_level]
      }

      # Only update these if we have values and existing is empty
      update_data[:website] = partner[:website] if partner[:website].present? && existing.website.blank?
      update_data[:city] = partner[:city] if partner[:city].present? && existing.city.blank?
      update_data[:state] = partner[:state] if partner[:state].present? && existing.state.blank?
      update_data[:country] = partner[:country] if partner[:country].present? && existing.country.blank?
      update_data[:servicenow_url] = partner[:servicenow_url] if partner[:servicenow_url].present?

      existing.update!(update_data)
      { action: :updated, name: partner[:name], matched_as: existing.name, match_type: match_type }
    else
      Company.create!(
        name: partner[:name],
        is_partner: true,
        is_customer: false,
        active: true,
        website: partner[:website],
        city: partner[:city],
        state: partner[:state],
        country: partner[:country],
        build_level: partner[:build_level],
        consulting_level: partner[:consulting_level],
        reseller_level: partner[:reseller_level],
        service_provider_level: partner[:service_provider_level],
        partner_level: partner[:partner_level],
        servicenow_url: partner[:servicenow_url],
        last_fetched_at: now,
        last_found_in_partner_list: now
      )
      { action: :created, name: partner[:name] }
    end
  end

  def find_existing_company(partner)
    # First try exact name match
    existing = Company.find_by(name: partner[:name])
    return [ existing, :name ] if existing

    # Try matching by website domain
    if partner[:website].present?
      domain = extract_domain(partner[:website])
      if domain
        Company.where("website LIKE ?", "%#{domain}%").find_each do |company|
          if extract_domain(company.website) == domain
            return [ company, :website ]
          end
        end
      end
    end

    [ nil, nil ]
  end

  def extract_domain(url)
    return nil if url.blank?
    url = "https://#{url}" unless url.start_with?("http")
    URI.parse(url).host&.sub(/^www\./, "")&.downcase
  rescue URI::InvalidURIError
    nil
  end

  def schedule_next_run
    # Run again in 1 day
    FetchPartnersJob.set(wait: 1.day).perform_later
  end
end
