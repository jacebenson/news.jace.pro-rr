class FetchSecFilingsJob < ApplicationJob
  queue_as :default

  # ServiceNow's CIK number with the SEC
  CIK = "0001373715"

  # SEC requires a User-Agent header with contact info
  SEC_HEADERS = {
    "User-Agent" => "NewsBot (contact@example.com)",
    "Accept" => "application/json"
  }.freeze

  FORM_TYPES = {
    "10-K" => "Annual Report",
    "10-Q" => "Quarterly Report",
    "8-K" => "Major Event Report"
  }.freeze

  def perform
    Rails.logger.info "[SEC] Starting FetchSecFilingsJob"
    job_start = Time.current

    cik_padded = CIK.rjust(10, "0")

    # Fetch all filings from SEC EDGAR
    filings = fetch_filings(CIK)
    Rails.logger.info "[SEC] Found #{filings.length} relevant filings (10-K, 10-Q, 8-K)"

    summarized = 0
    updated = 0
    skipped = 0
    errors = 0

    filings.each_with_index do |filing, idx|
      begin
        # Check if already summarized
        existing = ServicenowInvestment.find_by(url: filing[:html_link])

        if existing&.summary.present?
          Rails.logger.debug "[SEC] Already summarized: #{filing[:filing_date]} #{filing[:form]}"
          skipped += 1
          next
        end

        # Get the filing content
        content = fetch_filing_content(filing, cik_padded)
        next unless content.present?

        # Get AI summary
        summary = get_summary(content)

        if existing
          existing.update!(
            date: Date.parse(filing[:filing_date]),
            content: content,
            summary: summary
          )
          updated += 1
          Rails.logger.info "[SEC] Updated: #{filing[:filing_date]} #{filing[:form]}"
        else
          ServicenowInvestment.create!(
            investment_type: FORM_TYPES[filing[:form]],
            date: Date.parse(filing[:filing_date]),
            url: filing[:html_link],
            content: content,
            summary: summary
          )
          summarized += 1
          Rails.logger.info "[SEC] Created: #{filing[:filing_date]} #{filing[:form]}"
        end

        # Rate limit - SEC asks for max 10 requests per second
        sleep(0.2)
      rescue => e
        errors += 1
        Rails.logger.error "[SEC] Error processing #{filing[:form]} #{filing[:filing_date]}: #{e.message}"
      end

      # Progress log
      if (idx + 1) % 10 == 0
        Rails.logger.info "[SEC] Progress: #{idx + 1}/#{filings.length}"
      end
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[SEC] === Summary ==="
    Rails.logger.info "[SEC] New: #{summarized}, Updated: #{updated}, Skipped: #{skipped}, Errors: #{errors}"
    Rails.logger.info "[SEC] Completed in #{elapsed}s"

    # Schedule next run in 1 day
    schedule_next_run

    { summarized: summarized, updated: updated, skipped: skipped, errors: errors }
  end

  private

  def fetch_filings(cik)
    cik_padded = cik.rjust(10, "0")
    url = "https://data.sec.gov/submissions/CIK#{cik}.json"

    response = HTTParty.get(url, headers: SEC_HEADERS, timeout: 30)
    return [] unless response.success?

    data = response.parsed_response
    filings = data.dig("filings", "recent") || {}

    # Also fetch older filings if they exist
    old_filing_files = data.dig("filings", "files") || []
    if old_filing_files.any?
      Rails.logger.info "[SEC] Fetching #{old_filing_files.length} older filing archives"
      old_filings = fetch_old_filings(old_filing_files)
      filings = merge_filings(filings, old_filings)
    end

    # Build list of filings
    filings_list = []
    accession_numbers = filings["accessionNumber"] || []

    accession_numbers.each_with_index do |accession_number, i|
      form = filings["form"][i]
      next unless FORM_TYPES.key?(form)

      accession_no_dashes = accession_number.delete("-")
      filings_list << {
        accession_number: accession_number,
        filing_date: filings["filingDate"][i],
        report_date: filings["reportDate"][i],
        form: form,
        primary_document: filings["primaryDocument"][i],
        html_link: "https://www.sec.gov/Archives/edgar/data/#{cik_padded}/#{accession_number}-index.htm",
        json_link: "https://www.sec.gov/Archives/edgar/data/#{cik_padded}/#{accession_no_dashes}/index.json"
      }
    end

    filings_list
  end

  def fetch_old_filings(files)
    combined = {}

    files.each do |file|
      response = HTTParty.get(
        "https://data.sec.gov/submissions/#{file['name']}",
        headers: SEC_HEADERS,
        timeout: 30
      )
      next unless response.success?

      data = response.parsed_response
      data.each do |key, value|
        if combined[key]
          combined[key] = combined[key] + value
        else
          combined[key] = value
        end
      end

      sleep(0.1) # Rate limit
    end

    combined
  end

  def merge_filings(recent, old)
    return recent if old.empty?

    recent.each do |key, value|
      if old[key].is_a?(Array)
        recent[key] = value + old[key]
      end
    end

    recent
  end

  def fetch_filing_content(filing, cik_padded)
    # Get the index.json to find the .txt file
    response = HTTParty.get(filing[:json_link], headers: SEC_HEADERS, timeout: 30)
    return nil unless response.success?

    data = response.parsed_response

    # Handle case where SEC returns string instead of hash
    unless data.is_a?(Hash)
      Rails.logger.error "[SEC] Expected JSON hash but got: #{data.class}"
      return nil
    end

    items = data.dig("directory", "item") || []

    # Find the main .txt file
    txt_file = items.find { |item| item["name"] == "#{filing[:accession_number]}.txt" }
    return nil unless txt_file

    accession_no_dashes = filing[:accession_number].delete("-")
    file_url = "https://www.sec.gov/Archives/edgar/data/#{cik_padded}/#{accession_no_dashes}/#{txt_file['name']}"

    # Fetch the file content
    response = HTTParty.get(file_url, headers: SEC_HEADERS, timeout: 60)
    return nil unless response.success?

    # Extract the first document and convert to markdown
    text = response.body
    document = text.split("</DOCUMENT>").first
    document = document.split("SECURITIES AND EXCHANGE COMMISSION").last if document.include?("SECURITIES AND EXCHANGE COMMISSION")

    # Convert HTML to markdown
    ReverseMarkdown.convert(document || "", unknown_tags: :bypass)
  rescue => e
    Rails.logger.error "[SEC] Error fetching content: #{e.message}"
    nil
  end

  def get_summary(content)
    # Prefer OpenAI (more reliable), fall back to Gemini
    if ENV["OPENAI_API_KEY"].present?
      get_summary_openai(content)
    elsif ENV["GEMINI_API_KEY"].present?
      get_summary_gemini(content)
    else
      nil
    end
  end

  def get_summary_gemini(content)
    # Truncate content if too long
    truncated = content.length > 50000 ? content[0, 50000] + "...[truncated]" : content

    client = OpenAI::Client.new(
      access_token: ENV["GEMINI_API_KEY"],
      uri_base: "https://generativelanguage.googleapis.com/v1beta/openai/"
    )

    # Rate limit for Gemini
    sleep(2)

    response = client.chat(
      parameters: {
        model: "gemini-2.0-flash-exp",
        messages: [
          { role: "system", content: "You are a distiller of information." },
          { role: "user", content: summary_prompt(truncated) }
        ]
      }
    )

    response.is_a?(Hash) ? response.dig("choices", 0, "message", "content") : nil
  rescue => e
    Rails.logger.error "[SEC] Gemini error: #{e.message}"
    # Fall back to OpenAI
    get_summary_openai(content) if ENV["OPENAI_API_KEY"].present?
  end

  def get_summary_openai(content)
    # Truncate content if too long
    truncated = content.length > 50000 ? content[0, 50000] + "...[truncated]" : content

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    response = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "You are a distiller of information." },
          { role: "user", content: summary_prompt(truncated) }
        ]
      }
    )

    response.is_a?(Hash) ? response.dig("choices", 0, "message", "content") : nil
  rescue => e
    Rails.logger.error "[SEC] OpenAI error: #{e.message}"
    nil
  end

  def summary_prompt(content)
    <<~PROMPT
      You will take any text and pull out the most important details pertaining to acquisitions, mergers, and other notable items. You will return a one liner for each item.

      #{content}
    PROMPT
  end

  def schedule_next_run
    # Run again in 1 day
    FetchSecFilingsJob.set(wait: 1.day).perform_later
  end
end
