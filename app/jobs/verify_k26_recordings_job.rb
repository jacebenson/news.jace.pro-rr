class VerifyK26RecordingsJob < ApplicationJob
  queue_as :default
  
  require 'net/http'
  require 'uri'
  
  def perform(sample_size: nil)
    Rails.logger.info "[VerifyK26RecordingsJob] Starting K26 recording URL verification..."
    
    # Get K26 sessions with recording URLs
    sessions = KnowledgeSession
      .for_event("k26")
      .where.not(recording_url: nil)
      .where.not(recording_url: "")
    
    sessions = sessions.limit(sample_size) if sample_size
    
    valid_count = 0
    invalid_count = 0
    invalid_sessions = []
    
    sessions.find_each do |session|
      if verify_video_exists(session.recording_url)
        valid_count += 1
        Rails.logger.info "[VerifyK26RecordingsJob] ✓ Valid: #{session.code}"
      else
        invalid_count += 1
        invalid_sessions << session.code
        Rails.logger.warn "[VerifyK26RecordingsJob] ✗ Invalid: #{session.code} - clearing URL"
        session.update_column(:recording_url, nil)
      end
    end
    
    Rails.logger.info "[VerifyK26RecordingsJob] Completed. Valid: #{valid_count}, Invalid: #{invalid_count}"
    
    {
      valid: valid_count,
      invalid: invalid_count,
      invalid_codes: invalid_sessions,
      message: "Verification complete. #{valid_count} valid, #{invalid_count} invalid (cleared)."
    }
  end
  
  private
  
  def verify_video_exists(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    
    return false unless response.code.to_i == 200
    
    # Check the response body for error indicators
    body = response.body.to_s
    
    # Brightcove error indicators
    error_indicators = [
      'VIDEO_CLOUD_ERR_VIDEO_NOT_FOUND',
      '"error":',
      'video-not-found',
      'error-message',
      '"code":"VIDEO_NOT_FOUND"'
    ]
    
    # If any error indicator is found, the video doesn't exist
    error_indicators.each do |indicator|
      if body.include?(indicator)
        Rails.logger.debug "[VerifyK26RecordingsJob] Found error indicator '#{indicator}' in response"
        return false
      end
    end
    
    # Additional check: look for video data in the page
    # Valid videos usually have video metadata or player configuration
    has_video_data = body.include?('videoData') || 
                     body.include?('video_object') ||
                     body.include?('playerConfig') ||
                     body.match?(/"sources":\s*\[/)
    
    has_video_data
  rescue => e
    Rails.logger.error "[VerifyK26RecordingsJob] Error verifying #{url}: #{e.message}"
    false
  end
end
