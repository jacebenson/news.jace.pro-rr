#!/usr/bin/env ruby
# Script to merge newer data from Feb 8th CedarJS backup into Rails DB
# Run with: bin/rails runner scripts/merge_feb8_backup.rb

require 'sqlite3'

SOURCE_DB = '/home/jace/git/news.jace.pro/api/db/2026-02-08.db'

unless File.exist?(SOURCE_DB)
  puts "ERROR: Source database not found: #{SOURCE_DB}"
  exit 1
end

source = SQLite3::Database.new(SOURCE_DB)
source.results_as_hash = true

# Helper to convert camelCase to snake_case
def to_snake(str)
  str.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')
end

# Helper to convert milliseconds to Time
def ms_to_time(ms)
  return nil if ms.nil? || ms == 0
  Time.at(ms / 1000.0)
end

# Helper to clean string content (removes null bytes, CDATA wrappers, fixes encoding)
def clean_string(str)
  return nil if str.nil?

  # Dup to unfreeze, handle encoding
  cleaned = str.dup.force_encoding('UTF-8')

  # Remove null bytes and other control characters (except newlines/tabs)
  cleaned.gsub!(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')

  # Remove CDATA wrappers (both escaped and unescaped variants)
  cleaned.gsub!(/^<!\\\[CDATA\\\[\s*/i, '')  # Escaped version: <!\[CDATA\[
  cleaned.gsub!(/^<!\[CDATA\[\s*/i, '')      # Unescaped version: <![CDATA[
  cleaned.gsub!(/\s*\\\]\\\]>$/i, '')        # Escaped closing: \]\]>
  cleaned.gsub!(/\s*\]\]>$/i, '')            # Unescaped closing: ]]>

  # Replace invalid UTF-8 sequences
  cleaned.encode!('UTF-8', invalid: :replace, undef: :replace, replace: '')

  cleaned.strip
end

puts "=" * 60
puts "Merging data from Feb 8th backup into Rails DB"
puts "=" * 60

# ============================================================================
# NEWS ITEMS
# ============================================================================
puts "\n=== News Items ==="

# Get the max created_at from Rails DB (in milliseconds)
max_created_ms = NewsItem.maximum("CAST(strftime('%s', created_at) AS INTEGER) * 1000") || 0
puts "Rails DB newest: #{ms_to_time(max_created_ms)}"

# Find newer items in source
newer_items = source.execute("SELECT * FROM NewsItem WHERE createdAt > ? ORDER BY createdAt ASC", [ max_created_ms ])
puts "Found #{newer_items.length} newer items in source"

imported_items = 0
skipped_items = 0

newer_items.each do |row|
  # Skip if URL already exists
  if NewsItem.exists?(url: row['url'])
    skipped_items += 1
    next
  end

  begin
    NewsItem.create!(
      id: row['id'],
      item_type: row['type'] || 'article',
      active: row['active'] == 1,
      state: row['state'] || 'new',
      title: clean_string(row['title']),
      body: clean_string(row['body']),
      url: row['url'],
      image_url: row['imageUrl'],
      duration: row['duration'],
      published_at: ms_to_time(row['publishedAt']),
      event_start: ms_to_time(row['eventStart']),
      event_end: ms_to_time(row['eventEnd']),
      event_location: row['eventLocation'],
      ad_url: row['adUrl'],
      call_to_action: row['callToAction'],
      news_feed_id: row['newsFeedId'],
      created_at: ms_to_time(row['createdAt']),
      updated_at: ms_to_time(row['updatedAt'])
    )
    imported_items += 1
  rescue ActiveRecord::RecordNotUnique => e
    skipped_items += 1
  rescue => e
    puts "  Error importing item #{row['id']}: #{e.message}"
    skipped_items += 1
  end
end

puts "Imported: #{imported_items}, Skipped: #{skipped_items}"

# ============================================================================
# SERVICENOW STORE APPS
# ============================================================================
puts "\n=== ServiceNow Store Apps ==="

# Get existing app IDs
existing_app_ids = ServicenowStoreApp.pluck(:source_app_id)
puts "Rails DB has #{existing_app_ids.length} apps"

# Find apps in source that don't exist in Rails
all_source_apps = source.execute("SELECT * FROM ServiceNowStoreApp")
new_apps = all_source_apps.reject { |row| existing_app_ids.include?(row['sourceAppId']) }
puts "Found #{new_apps.length} new apps in source"

imported_apps = 0

new_apps.each do |row|
  begin
    ServicenowStoreApp.create!(
      source_app_id: row['sourceAppId'],
      title: clean_string(row['title']),
      tagline: clean_string(row['tagline']),
      store_description: clean_string(row['storeDescription']),
      company_name: clean_string(row['companyName']),
      company_logo: row['companyLogo'],
      logo: row['logo'],
      app_type: row['appType'],
      app_sub_type: row['appSubType'],
      version: row['version'],
      versions_data: row['versionsData'],
      purchase_count: row['purchaseCount'],
      review_count: row['reviewCount'],
      table_count: row['tableCount'],
      key_features: clean_string(row['keyFeatures']),
      business_challenge: clean_string(row['businessChallenge']),
      system_requirements: clean_string(row['systemRequirements']),
      supporting_media: row['supportingMedia'],
      support_links: row['supportLinks'],
      support_contacts: row['supportContacts'],
      purchase_trend: row['purchaseTrend'],
      display_price: row['displayPrice'],
      landing_page: row['landingPage'],
      allow_for_existing_customers: row['allowForExistingCustomers'] == 1,
      allow_for_non_customers: row['allowForNonCustomers'] == 1,
      allow_on_customer_subprod: row['allowOnCustomerSubprod'] == 1,
      allow_on_developer_instance: row['allowOnDeveloperInstance'] == 1,
      allow_on_servicenow_instance: row['allowOnServicenowInstance'] == 1,
      allow_trial: row['allowTrial'] == 1,
      allow_without_license: row['allowWithoutLicense'] == 1,
      last_fetched_at: ms_to_time(row['lastFetchedAt']),
      published_at: ms_to_time(row['publishedAt'])
    )
    imported_apps += 1
  rescue => e
    puts "  Error importing app #{row['sourceAppId']}: #{e.message}"
  end
end

puts "Imported: #{imported_apps}"

# ============================================================================
# COMPANIES
# ============================================================================
puts "\n=== Companies ==="

# Get existing company names
existing_company_names = Company.pluck(:name).map(&:downcase)
puts "Rails DB has #{existing_company_names.length} companies"

# Find companies in source that don't exist in Rails
all_source_companies = source.execute("SELECT * FROM Company")
new_companies = all_source_companies.reject { |row| existing_company_names.include?(row['name']&.downcase) }
puts "Found #{new_companies.length} new companies in source"

imported_companies = 0

new_companies.each do |row|
  begin
    Company.create!(
      name: clean_string(row['name']),
      alias: row['alias'] || '[]',
      active: row['active'] == 1,
      is_customer: row['isCustomer'] == 1,
      is_partner: row['isPartner'] == 1,
      website: row['website'],
      image_url: row['imageUrl'],
      notes: clean_string(row['notes']),
      city: row['city'],
      state: row['state'],
      country: row['country'],
      build_level: row['buildLevel'],
      consulting_level: row['consultingLevel'],
      reseller_level: row['resellerLevel'],
      service_provider_level: row['serviceProviderLevel'],
      partner_level: row['partnerLevel'],
      servicenow_url: row['serviceNowUrl'],
      rss_feed_url: row['rssFeedUrl'],
      servicenow_page_url: row['serviceNowPageUrl'],
      products: row['products'] || '[]',
      services: row['services'] || '[]',
      last_fetched_at: ms_to_time(row['lastFetchedAt']),
      last_sitemap_check: ms_to_time(row['lastSitemapCheck']),
      has_sitemap: row['hasSitemap'] == 1,
      last_found_in_partner_list: ms_to_time(row['lastFoundInPartnerList']),
      locked_fields: row['lockedFields'] || '[]'
    )
    imported_companies += 1
  rescue ActiveRecord::RecordNotUnique => e
    # Already exists
  rescue => e
    puts "  Error importing company #{row['name']}: #{e.message}"
  end
end

puts "Imported: #{imported_companies}"

# ============================================================================
# PARTICIPANTS
# ============================================================================
puts "\n=== Participants ==="

# Get existing participant names
existing_participant_names = Participant.pluck(:name).map(&:downcase)
puts "Rails DB has #{existing_participant_names.length} participants"

# Find participants in source that don't exist in Rails
all_source_participants = source.execute("SELECT * FROM Participant")
new_participants = all_source_participants.reject { |row| existing_participant_names.include?(row['name']&.downcase) }
puts "Found #{new_participants.length} new participants in source"

imported_participants = 0

new_participants.each do |row|
  begin
    Participant.create!(
      name: clean_string(row['name']),
      alias: row['alias'],
      company_name: clean_string(row['company']),
      title: clean_string(row['title']),
      bio: clean_string(row['bio']),
      image_url: row['imageUrl'],
      linkedin_url: row['linkedinUrl'],
      user_id: nil,  # Don't try to map user IDs
      company_id: nil  # Will be linked by LinkParticipantsJob
    )
    imported_participants += 1
  rescue ActiveRecord::RecordNotUnique => e
    # Already exists
  rescue => e
    puts "  Error importing participant #{row['name']}: #{e.message}"
  end
end

puts "Imported: #{imported_participants}"

# ============================================================================
# SUMMARY
# ============================================================================
puts "\n" + "=" * 60
puts "MERGE COMPLETE"
puts "=" * 60
puts "News Items:    +#{imported_items}"
puts "Store Apps:    +#{imported_apps}"
puts "Companies:     +#{imported_companies}"
puts "Participants:  +#{imported_participants}"
puts "\nRun LinkParticipantsJob to link new participants to companies:"
puts "  LinkParticipantsJob.perform_now"
