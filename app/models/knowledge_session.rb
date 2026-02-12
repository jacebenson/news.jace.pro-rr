class KnowledgeSession < ApplicationRecord
  has_many :knowledge_session_participants, dependent: :destroy
  has_many :speakers, through: :knowledge_session_participants, source: :participant

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

  # Scope to get sessions by short event name (k20, k21, etc.)
  scope :for_event, ->(short_name) {
    event_id = EVENT_IDS[short_name.to_sym]
    if event_id
      where(event_id: event_id)
    else
      none
    end
  }

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
end
