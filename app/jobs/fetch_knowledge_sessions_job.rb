class FetchKnowledgeSessionsJob < ApplicationJob
  queue_as :default

  # Rainfocus API configuration for each event
  # These values come from the Knowledge conference website
  EVENTS = {
    "k26" => {
      profile_id: "JAvhORLUccFlVdR8aw2ycCCY2Ae28oVG",
      widget_id: "noGq0udyhn10LXipqmfRdrkNBb5ohGMK",
      catalog_tab: "1720557007473001hkMD",
      event_id: "1754425456386001bk26"
    },
    "k25" => {
      profile_id: "U8KFzFiCft4fVAbeHhjGgH7BKEULqdWB",
      catalog_tab: "1720557007473001hkMD",
      event_id: "1710352571426001sJeH"
    }
  }.freeze

  def perform(event: "k26")
    config = EVENTS[event]
    unless config
      Rails.logger.error "[KNOWLEDGE] Unknown event: #{event}"
      return
    end

    Rails.logger.info "[KNOWLEDGE] Fetching #{event.upcase} sessions from Rainfocus API..."

    all_events = []
    fetch_all_sessions(config, all_events)

    Rails.logger.info "[KNOWLEDGE] Total sessions fetched: #{all_events.length}"

    created = 0
    updated = 0

    all_events.each do |session_data|
      result = upsert_session(session_data, config[:event_id])
      if result == :created
        created += 1
      elsif result == :updated
        updated += 1
      end
    end

    Rails.logger.info "[KNOWLEDGE] Completed: #{created} created, #{updated} updated"

    # Schedule next run in 15 minutes
    self.class.set(wait: 15.minutes).perform_later(event: event)
  end

  private

  def fetch_all_sessions(config, all_events, from: 0)
    response = make_api_request(config, from)

    return all_events unless response

    items = extract_items(response)
    simplified = items.map { |item| simplify_event(item) }
    all_events.concat(simplified)

    total = response["total"] || response["totalSearchItems"]
    Rails.logger.info "[KNOWLEDGE] Fetched #{simplified.length} sessions (#{from}-#{from + 50} of #{total || 'unknown'})"

    # Continue fetching if there are more
    if total && from + 50 < total
      fetch_all_sessions(config, all_events, from: from + 50)
    elsif total.nil? && simplified.length == 50
      # No total provided but got full page - fetch next
      fetch_all_sessions(config, all_events, from: from + 50)
    end

    all_events
  end

  def make_api_request(config, from)
    uri = URI("https://events.rainfocus.com/api/search")

    # Allow overriding profile_id and widget_id via env vars when authenticated
    profile_id = ENV["RAINFOCUS_PROFILE_ID"].presence || config[:profile_id]
    widget_id = ENV["RAINFOCUS_WIDGET_ID"].presence || config[:widget_id]

    headers = {
      "Accept" => "*/*",
      "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
      "Origin" => "https://knowledge.servicenow.com",
      "Referer" => "https://knowledge.servicenow.com/",
      "rfapiprofileid" => profile_id
    }
    headers["rfwidgetid"] = widget_id if widget_id
    headers["rfauthtoken"] = ENV["RAINFOCUS_AUTH_TOKEN"] if ENV["RAINFOCUS_AUTH_TOKEN"].present?

    body = URI.encode_www_form({
      "tab.catalogtab" => config[:catalog_tab],
      "search" => "",
      "type" => "session",
      "browserTimezone" => "America/Chicago",
      "catalogDisplay" => "list",
      "from" => from.to_s,
      "top" => "50"
    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, headers)
    request.body = body

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error "[KNOWLEDGE] API error: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "[KNOWLEDGE] Request failed: #{e.message}"
    nil
  end

  def extract_items(response)
    items = response.dig("sectionList", 0, "items")
    items ||= response["items"] || []
    items
  end

  def simplify_event(event)
    participants = parse_participants(event["participants"])
    times = parse_times(event["times"])
    abstract = sanitize_html(event["abstract"])

    {
      code: event["code"],
      session_id: event["externalID"],
      title: event["title"],
      title_sort: event["title_sort"] || event["title"]&.downcase&.gsub(/^(the|a|an)\s+/i, ""),
      abstract: abstract,
      published: event["published"]&.to_s,
      modified: event["modified"],
      participants: participants.to_json,
      times: times.to_json
    }
  end

  def parse_participants(raw_participants)
    return [] unless raw_participants.is_a?(Array)

    raw_participants.map do |p|
      {
        fullName: p["fullName"],
        photoURL: p["photoURL"],
        company: p["companyName"],
        title: p["jobTitle"],
        bio: p["globalBio"],
        sessionCount: p["session"]&.length || 0
      }
    end
  rescue => e
    Rails.logger.warn "[KNOWLEDGE] Error parsing participants: #{e.message}"
    []
  end

  def parse_times(raw_times)
    return [] unless raw_times.is_a?(Array)

    raw_times.map do |t|
      {
        date: t["date"],
        capacity: t["capacity"],
        seatsRemaining: t["seatsRemaining"],
        waitlistRemaining: t["waitlistRemaining"],
        startTimeFormatted: t["startTimeFormatted"],
        endTimeFormatted: t["endTimeFormatted"],
        length: "#{t['length']} minutes",
        sessionId: t["sessionId"],
        sessionTimeID: t["sessionTimeID"],
        room: t["room"] || "TBD",
        dateFormatted: t["dateFormatted"]
      }
    end
  rescue => e
    Rails.logger.warn "[KNOWLEDGE] Error parsing times: #{e.message}"
    []
  end

  def sanitize_html(html)
    return "" if html.blank?

    # Simple HTML to text conversion
    text = html.gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/p>/i, "\n\n")
               .gsub(/<[^>]+>/, "")
               .gsub(/&nbsp;/, " ")
               .gsub(/&amp;/, "&")
               .gsub(/&lt;/, "<")
               .gsub(/&gt;/, ">")
               .gsub(/&quot;/, '"')
               .strip

    text
  end

  def upsert_session(session_data, event_id)
    session_data[:event_id] = event_id
    session_data[:last_seen_at] = Time.current

    existing = KnowledgeSession.find_by(session_id: session_data[:session_id])

    if existing
      existing.update!(session_data)
      upsert_participants(existing, session_data[:participants])
      :updated
    else
      session = KnowledgeSession.create!(session_data)
      upsert_participants(session, session_data[:participants])
      :created
    end
  rescue => e
    Rails.logger.error "[KNOWLEDGE] Error upserting session #{session_data[:code]}: #{e.message}"
    nil
  end

  def upsert_participants(db_session, participants_json)
    participants = JSON.parse(participants_json) rescue []

    participants.each do |p|
      next if p["fullName"].blank?

      participant_data = {
        name: p["fullName"],
        company_name: p["company"],
        image_url: p["photoURL"],
        bio: p["bio"],
        title: p["title"]
      }.compact

      participant = Participant.find_or_initialize_by(name: p["fullName"])

      if participant.new_record?
        participant.assign_attributes(participant_data)
      else
        # Always update these fields from API (keep data fresh)
        participant.company_name = p["company"] if p["company"].present?
        participant.title = p["title"] if p["title"].present?

        # Only fill in blank fields for these (don't overwrite curated data)
        participant.image_url = p["photoURL"] if participant.image_url.blank? && p["photoURL"].present?
        participant.bio = p["bio"] if participant.bio.blank? && p["bio"].present?
      end

      participant.save!

      # Link participant to session if not already linked (including hidden ones)
      # This preserves the hidden flag - we don't recreate hidden links
      unless KnowledgeSessionParticipant.exists?(
        knowledge_session_id: db_session.id,
        participant_id: participant.id
      )
        KnowledgeSessionParticipant.create!(
          knowledge_session_id: db_session.id,
          participant_id: participant.id,
          hidden: false
        )
      end
    rescue => e
      Rails.logger.warn "[KNOWLEDGE] Error upserting participant #{p['fullName']}: #{e.message}"
    end
  end
end
