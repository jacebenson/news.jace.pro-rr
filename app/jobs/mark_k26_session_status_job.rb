class MarkK26SessionStatusJob < ApplicationJob
  queue_as :default

  def perform
    k26_event_id = KnowledgeSession::EVENT_IDS[:k26]
    k26_start = KnowledgeSession::K26_START_DATE
    
    Rails.logger.info "[MarkK26SessionStatusJob] Starting K26 session status update..."
    
    # Find K26 sessions that were last seen before May 4, 2026
    # These are assumed to be canceled
    sessions_to_cancel = KnowledgeSession
      .where(event_id: k26_event_id)
      .where("last_seen_at < ?", k26_start)
      .where.not("code LIKE 'PARTY%'")
      .where(canceled_at: nil)
    
    canceled_count = 0
    sessions_to_cancel.find_each do |session|
      session.update_column(:canceled_at, Time.current)
      canceled_count += 1
      Rails.logger.info "[MarkK26SessionStatusJob] Marked as canceled: #{session.code} - #{session.title}"
    end
    
    Rails.logger.info "[MarkK26SessionStatusJob] Completed. Marked #{canceled_count} sessions as canceled."
    
    { 
      canceled: canceled_count,
      message: "Marked #{canceled_count} K26 sessions as canceled (last seen before May 4, 2026)"
    }
  end
end
