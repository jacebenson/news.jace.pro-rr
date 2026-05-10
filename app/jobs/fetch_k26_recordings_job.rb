class FetchK26RecordingsJob < ApplicationJob
  queue_as :default

  BRIGHTCOVE_BASE = "https://players.brightcove.net/5703385908001/zKNjJ2k2DM_default/index.html".freeze
  BRIGHTCOVE_API_BASE = "https://edge.api.brightcove.com/playback/v1/accounts/5703385908001/videos".freeze

  # Policy key for accessing the playback API (extracted from player page)
  POLICY_KEY = "BCpkADawqM10puDCjU1kN2Q_uSH88Mt4Q3lnff2P52BxeoyUb-ArQcO-o7cWhORTaxyJXoyq4RH203fbAMmv5TkO_KrZJlPP2X42T2ofBRNH8wfZdvogEwb4nS_TbFjjw9YqZvls_o7730Rl".freeze

  def perform(limit: nil)
    Rails.logger.info "[FetchK26RecordingsJob] Starting K26 recording URL verification..."

    # Get K26 sessions that don't have recording URLs yet
    sessions = KnowledgeSession
      .for_event("k26")
      .where(canceled_at: nil)
      .where("recording_url IS NULL OR recording_url = ''")
      .order(:title_sort)

    sessions = sessions.limit(limit) if limit

    updated_count = 0
    not_found = []

    sessions.find_each do |session|
      video_ref = "ref:#{session.code}-K26"

      if video_exists?(video_ref)
        video_url = "#{BRIGHTCOVE_BASE}?videoId=#{video_ref}"
        session.update!(recording_url: video_url)
        updated_count += 1
        Rails.logger.info "[FetchK26RecordingsJob] ✓ Found recording for #{session.code}"
      else
        not_found << session.code
        Rails.logger.debug "[FetchK26RecordingsJob] ✗ No recording for #{session.code}"
      end
    end

    Rails.logger.info "[FetchK26RecordingsJob] Completed. Found #{updated_count} recordings, #{not_found.count} not found."

    {
      updated: updated_count,
      not_found: not_found.count,
      message: "Found #{updated_count} valid recordings. #{not_found.count} sessions don't have videos available yet."
    }
  end

  private

  def video_exists?(video_ref)
    require "net/http"
    require "uri"
    require "json"

    # URL encode the video reference (e.g., ref:KEY10501-K26 -> ref%3AKEY10501-K26)
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

    # Check if we got a valid video response (200 with video data)
    if response.code.to_i == 200
      begin
        data = JSON.parse(response.body)
        # Valid videos have an 'id' field and sources
        data["id"].present? && data["sources"].present?
      rescue JSON::ParserError
        false
      end
    else
      false
    end
  rescue => e
    Rails.logger.debug "[FetchK26RecordingsJob] Error checking #{video_ref}: #{e.message}"
    false
  end
end
