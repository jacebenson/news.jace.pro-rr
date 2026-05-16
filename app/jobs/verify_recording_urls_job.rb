class VerifyRecordingUrlsJob < ApplicationJob
  queue_as :default

  # Policy keys for different Brightcove accounts
  # Main ServiceNow account
  POLICY_KEY_MAIN = "BCpkADawqM10puDCjU1kN2Q_uSH88Mt4Q3lnff2P52BxeoyUb-ArQcO-o7cWhORTaxyJXoyq4RH203fbAMmv5TkO_KrZJlPP2X42T2ofBRNH8wfZdvogEwb4nS_TbFjjw9YqZvls_o7730Rl".freeze
  # TODO: Add policy key for account 5993042352001 if available
  # POLICY_KEY_SECONDARY = "...".freeze

  # URL patterns vary by year
  REF_PATTERNS = {
    "k20" => ->(code) { "ref:K20-#{code}" },
    "k21" => ->(code) { "ref:#{code}-K21" },
    "k22" => ->(code) { "ref:#{code}-SDR22" },
    "k23" => ->(code) { "ref:#{code}-K23" },
    "k24" => ->(code) { "ref:#{code}-K24" },
    "k25" => ->(code) { "ref:#{code}-K25" },
    "k26" => ->(code) { "ref:#{code}-K26" }
  }.freeze

  def perform(event: nil)
    if event.present?
      verify_event(event)
    else
      # Verify all events
      results = {}
      REF_PATTERNS.keys.each do |evt|
        results[evt] = verify_event(evt)
      end
      results
    end
  end

  private

  def verify_event(event)
    Rails.logger.info "[VerifyRecordingUrlsJob] Verifying recordings for #{event.upcase}..."

    sessions = KnowledgeSession.for_event(event).where.not(recording_url: nil)
    total = sessions.count

    if total == 0
      message = "No recordings to verify for #{event.upcase}"
      Rails.logger.info "[VerifyRecordingUrlsJob] #{message}"
      return { event: event, checked: 0, valid: 0, cleared: 0, message: message }
    end

    pattern_lambda = REF_PATTERNS[event]
    if pattern_lambda.nil?
      message = "Unknown event pattern for #{event.upcase}, skipping"
      Rails.logger.warn "[VerifyRecordingUrlsJob] #{message}"
      return { event: event, checked: 0, valid: 0, cleared: 0, message: message }
    end

    valid = 0
    cleared = 0

    sessions.find_each.with_index do |session, idx|
      video_ref = pattern_lambda.call(session.code)

      # Extract account ID from the existing URL (handles multiple accounts like K20)
      account_id = extract_account_id(session.recording_url)

      if video_exists?(video_ref, account_id)
        valid += 1
      else
        session.update!(recording_url: nil)
        cleared += 1
        Rails.logger.info "[VerifyRecordingUrlsJob] Cleared invalid URL for #{session.code} (tried: #{video_ref}, account: #{account_id})"
      end

      if (idx + 1) % 50 == 0
        Rails.logger.info "[VerifyRecordingUrlsJob] #{event.upcase}: #{idx + 1}/#{total} checked, #{valid} valid, #{cleared} cleared"
      end
    end

    message = "#{event.upcase}: Checked #{total}, #{valid} valid, #{cleared} invalid URLs cleared"
    Rails.logger.info "[VerifyRecordingUrlsJob] #{message}"

    { event: event, checked: total, valid: valid, cleared: cleared, message: message }
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
    when "5993042352001"
      # Skip verification if we don't have the policy key for this account
      # Return true to preserve the URL (user can test manually)
      Rails.logger.warn "[VerifyRecordingUrlsJob] Cannot verify #{video_ref} on account #{account_id} - no policy key available"
      return true
    else
      # Unknown account - skip verification
      Rails.logger.warn "[VerifyRecordingUrlsJob] Unknown account #{account_id} for #{video_ref}, skipping verification"
      return true
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
