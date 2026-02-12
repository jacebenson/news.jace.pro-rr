module ApplicationHelper
  # Convert millisecond timestamp to Time object for time_ago_in_words
  # Also handles Time objects directly (for Rails native datetime columns)
  def ms_to_time(value)
    return nil if value.nil?
    # If it's already a Time object, return it as-is
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
    # Otherwise treat as milliseconds and convert
    Time.at(value / 1000.0)
  end

  # Extract YouTube video ID from URL
  def youtube_video_id(text)
    return nil if text.blank?
    # Match youtube.com/watch?v=CODE or youtu.be/CODE
    match = text.match(/youtube\.com\/watch\?v=([\w-]{11})/) || text.match(/youtu\.be\/([\w-]{11})/)
    match&.[](1)
  end

  # Generate YouTube embed HTML
  def youtube_embed_html(video_id)
    return "" if video_id.blank?
    %(<div class="aspect-video"><iframe class="w-full h-full rounded-lg" src="https://www.youtube.com/embed/#{video_id}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe></div>)
  end

  # Convert markdown-ish text to simple HTML
  def simple_markdown_to_html(text)
    return "" if text.blank?
    # Very basic markdown conversion
    html = ERB::Util.html_escape(text)
    html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    html = html.gsub(/\*(.+?)\*/, '<em>\1</em>')
    html = html.gsub(/`(.+?)`/, '<code>\1</code>')
    html = html.gsub(/\n/, "<br>")
    html.html_safe
  end

  # Render markdown to HTML using Redcarpet
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      underline: true,
      highlight: true,
      no_intra_emphasis: true
    )

    markdown.render(text).html_safe
  end

  # Podcast embed helpers
  # Returns the podcast platform type: :anchor, :transistor, :omny, or nil
  def podcast_platform(url)
    return nil if url.blank?
    return :anchor if url.include?("anchor.fm") || url.include?("podcasters.spotify.com")
    return :transistor if url.include?(".transistor.fm")
    return :omny if url.include?("omny.fm")
    nil
  end

  # Generate Anchor.fm/Spotify embed URL
  # URL format: https://podcasters.spotify.com/pod/show/{channelId}/episodes/{episodeId}
  # Embed format: https://anchor.fm/{channelId}/embed/episodes/{episodeId}
  def anchor_embed_url(url)
    return nil if url.blank?
    # Extract channel ID (after /pod/show/ or /show/)
    channel_match = url.match(/\/pod\/show\/([^\/]+)/) || url.match(/\/show\/([^\/]+)/)
    # Extract episode ID (after /episodes/)
    episode_match = url.match(/\/episodes\/(.+?)(?:\?|$)/)

    return nil unless channel_match && episode_match

    channel_id = channel_match[1]
    episode_id = episode_match[1]
    "https://anchor.fm/#{channel_id}/embed/episodes/#{episode_id}"
  end

  # Generate Transistor.fm embed URL
  # URL format: https://share.transistor.fm/s/{id}
  # Embed format: https://share.transistor.fm/e/{id}
  def transistor_embed_url(url)
    return nil if url.blank?
    url.gsub("/s/", "/e/")
  end

  # Generate Omny.fm embed URL
  # Just append /embed?style=Cover
  def omny_embed_url(url)
    return nil if url.blank?
    "#{url}/embed?style=Cover"
  end

  # Generate podcast embed HTML based on URL
  def podcast_embed_html(url, title = "Podcast")
    platform = podcast_platform(url)
    return "" if platform.nil?

    case platform
    when :anchor
      embed_url = anchor_embed_url(url)
      return "" if embed_url.nil?
      %(<div class="w-full p-4 bg-gradient-to-br from-green-50 to-green-100 rounded-lg">
        <iframe
          title="#{ERB::Util.html_escape(title)}"
          src="#{embed_url}"
          height="152"
          class="w-full rounded-lg"
          frameborder="0"
          scrolling="no"
          allow="autoplay; clipboard-write; encrypted-media">
        </iframe>
      </div>).html_safe
    when :transistor
      embed_url = transistor_embed_url(url)
      %(<div class="w-full max-w-3xl">
        <iframe
          title="#{ERB::Util.html_escape(title)}"
          src="#{embed_url}"
          height="180"
          class="w-full rounded-lg"
          frameborder="0"
          scrolling="no"
          seamless>
        </iframe>
      </div>).html_safe
    when :omny
      embed_url = omny_embed_url(url)
      %(<div class="w-full">
        <iframe
          title="#{ERB::Util.html_escape(title)}"
          src="#{embed_url}"
          height="200"
          class="w-full rounded-lg"
          frameborder="0"
          allow="autoplay; clipboard-write">
        </iframe>
      </div>).html_safe
    else
      ""
    end
  end
end
