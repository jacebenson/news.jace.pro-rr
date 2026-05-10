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

    sessions.find_each do |session|
      # Construct the video URL using the confirmed pattern
      video_url = "#{BRIGHTCOVE_BASE}?videoId=ref:#{session.code}-K26"

      # Note: We can't reliably verify Brightcove URLs via HTTP requests
      # since the player loads via JS and returns 200 even for missing videos.
      # We'll save the URL and let users verify by clicking.
      session.update!(recording_url: video_url)
      updated_count += 1
      Rails.logger.info "[FetchK26RecordingsJob] Added recording URL for #{session.code}: #{video_url}"
    end

    Rails.logger.info "[FetchK26RecordingsJob] Completed. Added #{updated_count} recording URLs."

    {
      updated: updated_count,
      message: "Added #{updated_count} recording URLs. Note: Not all videos may be available yet - click Watch to test."
    }
  end
end
