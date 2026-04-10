# RSS 2.0 feed for news items
# Reference: https://www.rssboard.org/rss-specification

# Helper to safely format dates for RSS (handles both Time and Integer timestamps)
# Note: stored timestamps are in milliseconds, so divide by 1000 for Time.at
def rss_date(value)
  return nil if value.nil?
  time = value.is_a?(Integer) ? Time.at(value / 1000.0) : value.to_time
  time.rfc2822
end

xml.instruct! :xml, version: "1.0", encoding: "UTF-8"

xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    # Required channel elements
    xml.title "News Jace Pro"
    xml.link request.base_url
    xml.description "ServiceNow ecosystem news, articles, podcasts, and videos"
    xml.language "en-us"

    # Atom self-link (helps feed readers identify the feed URL)
    xml.tag!("atom:link", href: request.original_url, rel: "self", type: "application/rss+xml")

    # Optional but useful channel elements
    xml.lastBuildDate rss_date(@news_items.first&.published_at)
    xml.generator "News Jace Pro"

    # Each news item becomes an <item> element
    @news_items.each do |item|
      xml.item do
        xml.title item.title
        xml.link item.url
        xml.description item.body
        xml.pubDate rss_date(item.published_at)
        xml.guid item.url, isPermaLink: "true"

        # Include participant names as categories
        item.participants.each do |participant|
          xml.category participant.name
        end
      end
    end
  end
end
