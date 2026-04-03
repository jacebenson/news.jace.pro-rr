class KnowledgeSession < ApplicationRecord
  # Normalize blank session_id to nil to avoid unique constraint violations
  before_validation :normalize_session_id

  has_many :knowledge_session_participants, dependent: :destroy
  has_many :speakers, -> { where(knowledge_session_participants: { hidden: false }) },
           through: :knowledge_session_participants, source: :participant
  has_many :all_speakers, through: :knowledge_session_participants, source: :participant

  has_many :knowledge_session_lists, dependent: :destroy
  has_many :users, through: :knowledge_session_lists

  scope :by_event, ->(event_id) { where(event_id: event_id) }
  scope :search, ->(term) { where("title LIKE ? OR abstract LIKE ?", "%#{term}%", "%#{term}%") }

  # Event ID constants - these are the actual values stored in the database
  EVENT_IDS = {
    k20: "k20",
    k21: "k21",
    k22: "k22",
    k23: "16590311612800012k23",
    k24: "1692646803067001xk24",
    k25: "1724429920965001dk25",
    k26: "1754425456386001bk26",
    nulledge25: "nulledge25"
  }.freeze

  # Human-readable event names
  EVENT_NAMES = {
    "k20" => "K20",
    "k21" => "K21",
    "k22" => "K22",
    "16590311612800012k23" => "K23",
    "1692646803067001xk24" => "K24",
    "1724429920965001dk25" => "K25",
    "1754425456386001bk26" => "K26",
    "nulledge25" => "nullEDGE 25"
  }.freeze

  # Scope to get sessions by short event name (k20, k21, etc.)
  scope :for_event, ->(short_name) {
    event_id = EVENT_IDS[short_name.to_sym]
    if event_id
      where(event_id: event_id)
    else
      none
    end
  }

  # Get human-readable event name
  def event_name
    EVENT_NAMES[event_id] || event_id&.upcase || "Conference"
  end

  # Get short event code (k20, k21, etc.) for URLs
  def event_short_code
    EVENT_IDS.key(event_id)&.to_s || event_id
  end

  # Get the URL to the session on knowledge.servicenow.com
  def knowledge_url
    return nil unless session_id.present?

    year = case event_id
    when "k20" then "k20"
    when "k21" then "k21"
    when "k22" then "k22"
    when "16590311612800012k23" then "k23"
    when "1692646803067001xk24" then "k24"
    when "1724429920965001dk25" then "k25"
    when "1754425456386001bk26" then "k26"
    else return nil
    end

    "https://knowledge.servicenow.com/flow/servicenow/#{year}/sessions/page/sessions/session/#{session_id}"
  end

  # Get the primary URL for this session
  # For parties/social events: uses the event URL
  # For regular sessions: uses the ServiceNow knowledge URL
  def primary_url
    # Priority: explicit event URL > knowledge URL
    return url if url.present?
    knowledge_url
  end

  # JSON array fields
  def participants_array
    JSON.parse(participants || "[]")
  rescue JSON::ParserError
    []
  end

  def times_array
    JSON.parse(times || "[]")
  rescue JSON::ParserError
    []
  end

  # Aliases for backward compatibility
  alias_method :participants_list, :participants_array
  alias_method :times_list, :times_array

  # Check if session is stale (not seen in API for 48+ hours)
  def stale?
    return false if code&.start_with?("PARTY") # Parties are manual, never stale
    return false if last_seen_at.nil? # Never fetched, can't determine
    last_seen_at < 48.hours.ago
  end

  # Scope for stale sessions (exclude parties - they're manual)
  scope :stale, -> { where("last_seen_at < ?", 48.hours.ago).where.not("code LIKE 'PARTY%'") }
  scope :active, -> { where("last_seen_at >= ? OR last_seen_at IS NULL OR code LIKE ?", 48.hours.ago, "PARTY%") }

  private

  def normalize_session_id
    if session_id.blank?
      # Auto-generate ISO timestamp as session_id for manually created sessions
      self.session_id = "manual-#{Time.current.utc.iso8601}"
    end
  end
end
