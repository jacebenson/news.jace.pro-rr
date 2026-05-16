class VerifyRecordingUrlsJob < ApplicationJob
  queue_as :default

  # Policy keys for different Brightcove accounts
  # Main ServiceNow account
  POLICY_KEY_MAIN = "BCpkADawqM10puDCjU1kN2Q_uSH88Mt4Q3lnff2P52BxeoyUb-ArQcO-o7cWhORTaxyJXoyq4RH203fbAMmv5TkO_KrZJlPP2X42T2ofBRNH8wfZdvogEwb4nS_TbFjjw9YqZvls_o7730Rl".freeze

  # URL patterns vary by year
  # K20-K23 codes already include year suffix in database
  # K24-K26 codes do NOT include year suffix
  REF_PATTERNS = {
    "k20" => ->(code) { "ref:#{code}" },        # Code is like "K20-THS1221"
    "k21" => ->(code) { "ref:#{code}" },        # Code is like "SPN1700-K21"
    "k22" => ->(code) { "ref:#{code}" },        # Code is like "KEY1084-SDR22"
    "k23" => ->(code) { "ref:#{code}" },        # Code is like "CCL1127-K23"
    "k24" => ->(code) { "ref:#{code}-K24" },    # Code is like "CCB1106"
    "k25" => ->(code) { "ref:#{code}-K25" },    # Code is like "CCB1161"
    "k26" => ->(code) { "ref:#{code}-K26" }     # Code is like "CCB6828"
  }.freeze

  def perform(event: nil, dry_run: true)
    if event.present?
      verify_event(event, dry_run: dry_run)
    else
      # Verify all events
      results = {}
      REF_PATTERNS.keys.each do |evt|
        results[evt] = verify_event(evt, dry_run: dry_run)
      end
      results
    end
  end

  private

  def verify_event(event, dry_run: true)
    Rails.logger.info "[VerifyRecordingUrlsJob] #{dry_run ? "DRY RUN - Reporting" : "Clearing"} recordings for #{event.upcase}..."

    sessions = KnowledgeSession.for_event(event).where.not(recording_url: nil)
    total = sessions.count

    if total == 0
      message = "No recordings to verify for #{event.upcase}"
      Rails.logger.info "[VerifyRecordingUrlsJob] #{message}"
      return { event: event, checked: 0, valid: 0, invalid: 0, cleared: 0, message: message, invalid_codes: [] }
    end

    pattern_lambda = REF_PATTERNS[event]
    if pattern_lambda.nil?
      message = "Unknown event pattern for #{event.upcase}, skipping"
      Rails.logger.warn "[VerifyRecordingUrlsJob] #{message}"
      return { event: event, checked: 0, valid: 0, invalid: 0, cleared: 0, message: message, invalid_codes: [] }
    end

    valid = 0
    invalid = []
    skipped = []

    sessions.find_each.with_index do |session, idx|
      video_ref = pattern_lambda.call(session.code)

      # Extract account ID from the existing URL (handles multiple accounts like K20)
      account_id = extract_account_id(session.recording_url)

      # Skip verification for accounts without policy keys
      if account_id != "5703385908001"
        skipped << { code: session.code, account: account_id, reason: "No policy key for account #{account_id}" }
        Rails.logger.info "[VerifyRecordingUrlsJob] Skipping #{session.code} on account #{account_id}"
        next
      end

      if video_exists?(video_ref, account_id)
        valid += 1
      else
        invalid << session.code
        unless dry_run
          session.update!(recording_url: nil)
          Rails.logger.info "[VerifyRecordingUrlsJob] Cleared invalid URL for #{session.code}"
        end
      end

      if (idx + 1) % 50 == 0
        Rails.logger.info "[VerifyRecordingUrlsJob] #{event.upcase}: #{idx + 1}/#{total} checked, #{valid} valid, #{invalid.count} invalid"
      end
    end

    cleared_count = dry_run ? 0 : invalid.count
    action = dry_run ? "Would clear" : "Cleared"

    message = "#{event.upcase}: Checked #{total}, #{valid} valid, #{invalid.count} invalid (#{action} #{invalid.count}), #{skipped.count} skipped"
    Rails.logger.info "[VerifyRecordingUrlsJob] #{message}"

    # Log detailed results (visible in production logs too)
    Rails.logger.info "[VerifyRecordingUrlsJob] #{event.upcase} Results: Checked #{total}, Valid #{valid}, Invalid #{invalid.count}, Skipped #{skipped.count}"
    if invalid.any?
      invalid.each { |code| Rails.logger.info "[VerifyRecordingUrlsJob] INVALID: #{code}" }
    end
    if skipped.any?
      skipped.each { |s| Rails.logger.info "[VerifyRecordingUrlsJob] SKIPPED: #{s[:code]} (account: #{s[:account]})" }
    end

    {
      event: event,
      checked: total,
      valid: valid,
      invalid: invalid.count,
      cleared: cleared_count,
      skipped: skipped.count,
      message: message,
      invalid_codes: invalid,
      skipped_details: skipped
    }
  end

  def extract_account_id(recording_url)
    # Extract account ID from URL like:
    # https://players.brightcove.net/5703385908001/zKNjJ2k2DM_default/...
    # https://players.brightcove.net/5993042352001/ROIuYES7V_default/...
    match = recording_url.match(%r{/net/(\d+)/})
    match ? match[1] : "5703385908001" # Default to main account
  end

  def video_exists?(video_ref, account_id)
    require "net/http"
    require "uri"
    require "json"

    # Use appropriate policy key for the account
    policy_key = case account_id
    when "5703385908001"
      POLICY_KEY_MAIN
    else
      # Skip verification if we don't have the policy key for this account
      Rails.logger.warn "[VerifyRecordingUrlsJob] No policy key for account #{account_id}, skipping verification for #{video_ref}"
      return true # Return true to preserve the URL
    end

    brightcove_api_base = "https://edge.api.brightcove.com/playback/v1/accounts/#{account_id}/videos"

    encoded_ref = URI.encode_www_form_component(video_ref)
    url = "#{brightcove_api_base}/#{encoded_ref}"

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json;pk=#{policy_key}"
    request["Origin"] = "https://players.brightcove.net"
    request["Referer"] = "https://players.brightcove.net/"

    response = http.request(request)

    if response.code.to_i == 200
      begin
        data = JSON.parse(response.body)
        data["id"].present? && data["sources"].present?
      rescue JSON::ParserError
        false
      end
    else
      false
    end
  rescue => e
    Rails.logger.debug "[VerifyRecordingUrlsJob] Error checking #{video_ref} on account #{account_id}: #{e.message}"
    false
  end
end
