class ExtractVideoParticipantsJob < ApplicationJob
  queue_as :default

  # Extract participants from video transcripts using AI
  # Uses yt-dlp to get transcripts and OpenAI to extract speaker names

  def perform(video_url, session_id = nil)
    Rails.logger.info "[EXTRACT] Starting ExtractVideoParticipantsJob for #{video_url}"

    # Get transcript from video using yt-dlp
    transcript = get_transcript(video_url)

    if transcript[:error]
      Rails.logger.error "[EXTRACT] Failed to get transcript: #{transcript[:error]}"
      return { success: false, error: transcript[:error] }
    end

    if transcript[:text].blank?
      Rails.logger.error "[EXTRACT] No transcript found for video"
      return { success: false, error: "No transcript found" }
    end

    Rails.logger.info "[EXTRACT] Transcript length: #{transcript[:text].length}"

    # Extract participants using AI
    participants = extract_participants_with_ai(transcript[:text])
    Rails.logger.info "[EXTRACT] Found #{participants.length} participants"

    # Create/update participants in database and link to session
    created = []
    participants.each do |p|
      next if p["name"].blank? || p["name"].length < 3

      begin
        # Build create/update data - only include fields with valid values
        create_data = { name: p["name"] }
        update_data = {}

        if has_value?(p["company"])
          create_data[:company_name] = p["company"]
          update_data[:company_name] = p["company"]
        end

        if has_value?(p["title"])
          create_data[:title] = p["title"]
          update_data[:title] = p["title"]
        end

        participant = Participant.find_or_initialize_by(name: p["name"])
        if participant.new_record?
          participant.assign_attributes(create_data)
        else
          participant.assign_attributes(update_data)
        end
        participant.save!

        created << participant
        Rails.logger.info "[EXTRACT] Upserted: #{participant.name}"

        # Link participant to session if session_id provided
        if session_id.present?
          existing = KnowledgeSessionParticipant.find_by(
            knowledge_session_id: session_id,
            participant_id: participant.id
          )

          unless existing
            KnowledgeSessionParticipant.create!(
              knowledge_session_id: session_id,
              participant_id: participant.id
            )
            Rails.logger.info "[EXTRACT] Linked #{participant.name} to session #{session_id}"
          end
        end
      rescue => e
        Rails.logger.warn "[EXTRACT] Error processing #{p['name']}: #{e.message}"
      end
    end

    Rails.logger.info "[EXTRACT] Created/updated #{created.length} participants"

    {
      success: true,
      participants_found: participants.length,
      participants_created: created.length
    }
  end

  private

  def has_value?(v)
    v.present? && v != "null" && v != "undefined" && v.to_s.strip.present?
  end

  def get_transcript(url)
    # Use yt-dlp to get subtitles/transcript
    temp_file = "/tmp/transcript_#{SecureRandom.hex(8)}"

    begin
      # Try to get auto-generated subtitles first
      result = `yt-dlp --write-auto-sub --sub-lang en --skip-download --output "#{temp_file}" "#{url}" 2>&1`

      # Check for subtitle file (could be .en.vtt or .en.srt)
      sub_file = Dir.glob("#{temp_file}*.{vtt,srt}").first

      unless sub_file && File.exist?(sub_file)
        # Try manually added subtitles
        result = `yt-dlp --write-sub --sub-lang en --skip-download --output "#{temp_file}" "#{url}" 2>&1`
        sub_file = Dir.glob("#{temp_file}*.{vtt,srt}").first
      end

      unless sub_file && File.exist?(sub_file)
        return { error: "No subtitles available", output: result }
      end

      # Read and clean up the subtitle file
      content = File.read(sub_file)
      text = clean_subtitles(content)

      # Clean up temp files
      Dir.glob("#{temp_file}*").each { |f| File.delete(f) }

      { text: text }
    rescue => e
      { error: e.message }
    end
  end

  def clean_subtitles(content)
    lines = content.lines
    text_lines = []

    lines.each do |line|
      line = line.strip

      # Skip WebVTT header and timing lines
      next if line.empty?
      next if line.start_with?("WEBVTT")
      next if line.match?(/^\d+$/)  # SRT sequence numbers
      next if line.match?(/-->/)    # Timing lines
      next if line.match?(/^\d{2}:\d{2}/)  # Timestamp lines
      next if line.start_with?("NOTE")
      next if line.start_with?("Kind:")
      next if line.start_with?("Language:")

      # Remove positioning tags like <c>, </c>, etc.
      line = line.gsub(/<[^>]+>/, "")

      text_lines << line if line.present?
    end

    # Join and deduplicate consecutive identical lines (common in auto-subs)
    result = []
    text_lines.each do |line|
      result << line unless result.last == line
    end

    result.join(" ")
  end

  def extract_participants_with_ai(transcript)
    api_key = ENV["OPENAI_API_KEY"]
    unless api_key.present?
      Rails.logger.error "[EXTRACT] OPENAI_API_KEY not set"
      return []
    end

    client = OpenAI::Client.new(access_token: api_key)

    # Truncate transcript if too long (keep first ~20k chars for context)
    max_length = 20000
    truncated_transcript = if transcript.length > max_length
      transcript[0, max_length] + "...[truncated]"
    else
      transcript
    end

    prompt = <<~PROMPT
      Extract all speaker/participant names from this video transcript.
      This is from a ServiceNow Knowledge conference session.

      Return ONLY a JSON array of objects with this format:
      [{"name": "Full Name", "title": "Job Title or null", "company": "Company Name or null"}]

      Rules:
      - Only include REAL PERSON names (not product names, company names, or other terms)
      - Names should be properly capitalized (e.g., "Bill McDermott" not "bill mcdermott")
      - If you can identify their title or company from context, include it
      - If unsure about title/company, use null
      - Do not include generic terms like "speaker" or "host"
      - Return empty array [] if no clear names found

      Transcript:
      #{truncated_transcript}
    PROMPT

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content: "You extract speaker names from transcripts. Return only valid JSON arrays."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.1
        }
      )

      content = response.dig("choices", 0, "message", "content") || "[]"

      # Parse JSON from response (handle markdown code blocks)
      json_str = content
      if content.include?("```")
        json_str = content.gsub(/```json?\n?/, "").gsub(/```/, "")
      end

      participants = JSON.parse(json_str.strip)
      participants.is_a?(Array) ? participants : []
    rescue JSON::ParserError => e
      Rails.logger.error "[EXTRACT] JSON parse error: #{e.message}"
      []
    rescue => e
      Rails.logger.error "[EXTRACT] AI extraction error: #{e.message}"
      []
    end
  end
end
