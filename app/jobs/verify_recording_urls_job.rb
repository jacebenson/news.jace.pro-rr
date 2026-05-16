class VerifyRecordingUrlsJob < ApplicationJob
  queue_as :default

  # Policy key for accessing the Brightcove playback API
  POLICY_KEY = "BCpkADawqM10puDCjU1kN2Q_uSH88Mt4Q3lnff2P52BxeoyUb-ArQcO-o7cWhORTaxyJXoyq4RH203fbAMmv5TkO_KrZJlPP2X42T2ofBRNH8wfZdvogEwb4nS_TbFjjw9YqZvls_o7730Rl".freeze
  BRIGHTCOVE_API_BASE = "https://edge.api.brightcove.com/playback/v1/accounts/5703385908001/videos".freeze

  def perform(event: nil)
    if event.present?
      verify_event(event)
    else
      # Verify all events
      results = {}
      %w[k20 k21 k22 k23 k24 k25 k26].each do |evt|
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

    valid = 0
    cleared = 0

    sessions.find_each.with_index do |session, idx|
      # Extract year from event (k20 -> 20, k24 -> 24)
      year = event.gsub(/\D/, "")
      video_ref = "ref:#{session.code}-K#{year}"

      if video_exists?(video_ref)
        valid += 1
      else
        session.update!(recording_url: nil)
        cleared += 1
        Rails.logger.info "[VerifyRecordingUrlsJob] Cleared invalid URL for #{session.code}"
      end

      if (idx + 1) % 50 == 0
        Rails.logger.info "[VerifyRecordingUrlsJob] #{event.upcase}: #{idx + 1}/#{total} checked, #{valid} valid, #{cleared} cleared"
      end
    end

    message = "#{event.upcase}: Checked #{total}, #{valid} valid, #{cleared} invalid URLs cleared"
    Rails.logger.info "[VerifyRecordingUrlsJob] #{message}"

    { event: event, checked: total, valid: valid, cleared: cleared, message: message }
  end

  def video_exists?(video_ref)
    require "net/http"
    require "uri"
    require "json"

    encoded_ref = URI.encode_www_form_component(video_ref)
    url = "#{BRIGHTCOVE_API_BASE}/#{encoded_ref}"

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json;pk=#{POLICY_KEY}"
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
    Rails.logger.debug "[VerifyRecordingUrlsJob] Error checking #{video_ref}: #{e.message}"
    false
  end
end
