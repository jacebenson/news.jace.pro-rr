class FetchK26RecordingsJob < ApplicationJob
  queue_as :default
  
  BASE_URL = "https://www.servicenow.com/events/ondemand/knowledge".freeze
  BRIGHTCOVE_BASE = "https://players.brightcove.net/5703385908001/zKNjJ2k2DM_default/index.html".freeze
  
  def perform(limit: nil)
    Rails.logger.info "[FetchK26RecordingsJob] Starting K26 recording URL fetch..."
    
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
      # Try to construct the video URL directly using the pattern we confirmed
      video_url = "#{BRIGHTCOVE_BASE}?videoId=ref:#{session.code}-K26"
      
      # Verify the URL works by making a HEAD request
      if verify_url(video_url)
        session.update!(recording_url: video_url)
        updated_count += 1
        Rails.logger.info "[FetchK26RecordingsJob] Found recording for #{session.code}: #{video_url}"
      else
        not_found << session.code
        Rails.logger.debug "[FetchK26RecordingsJob] No recording found for #{session.code}"
      end
    end
    
    Rails.logger.info "[FetchK26RecordingsJob] Completed. Updated #{updated_count} sessions."
    
    {
      updated: updated_count,
      not_found: not_found.count,
      message: "Updated #{updated_count} K26 sessions with recording URLs. #{not_found.count} not found."
    }
  end
  
  private
  
  def verify_url(url)
    require 'net/http'
    require 'uri'
    
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5
    
    request = Net::HTTP::Head.new(uri.request_uri)
    response = http.request(request)
    
    # Brightcove returns 200 for valid videos, even if they need auth
    response.code.to_i == 200
  rescue => e
    Rails.logger.debug "[FetchK26RecordingsJob] Error verifying #{url}: #{e.message}"
    false
  end
end
