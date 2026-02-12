namespace :import do
  desc "Import all data from CedarJS SQLite database"
  task all: :environment do
    source_db = ENV["SOURCE_DB"] || "/home/jace/git/news.jace.pro/api/db/2026-01-31.db"

    unless File.exist?(source_db)
      puts "Source database not found: #{source_db}"
      puts "Set SOURCE_DB environment variable to the correct path"
      exit 1
    end

    require "sqlite3"
    db = SQLite3::Database.new(source_db)
    db.results_as_hash = true

    puts "Importing from: #{source_db}"
    puts "=" * 60

    # Import in dependency order
    Rake::Task["import:users"].invoke(db)
    Rake::Task["import:tags"].invoke(db)
    Rake::Task["import:companies"].invoke(db)
    Rake::Task["import:news_feeds"].invoke(db)
    Rake::Task["import:participants"].invoke(db)
    Rake::Task["import:news_items"].invoke(db)
    Rake::Task["import:news_item_participants"].invoke(db)
    Rake::Task["import:news_item_tags"].invoke(db)
    Rake::Task["import:knowledge_sessions"].invoke(db)
    Rake::Task["import:knowledge_session_participants"].invoke(db)
    Rake::Task["import:knowledge_session_lists"].invoke(db)
    Rake::Task["import:servicenow_store_apps"].invoke(db)
    Rake::Task["import:servicenow_investments"].invoke(db)

    puts "=" * 60
    puts "Import complete!"
  end

  task :users, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting Users..."
    count = 0
    skipped = 0
    seen_emails = Set.new

    db.execute("SELECT * FROM User ORDER BY id").each do |row|
      email_lower = row["email"]&.downcase
      if seen_emails.include?(email_lower)
        skipped += 1
        next
      end
      seen_emails.add(email_lower)

      User.create!(
        id: row["id"],
        email: row["email"],
        password_digest: row["hashedPassword"], # Already hashed
        name: row["name"],
        link: row["link"],
        roles: row["roles"] || "user",
        reset_token: row["resetToken"],
        reset_token_expires_at: row["resetTokenExpiresAt"]
      )
      count += 1
    end

    reset_pk_sequence("users")
    puts "  Imported #{count} users (skipped #{skipped} duplicates)"
  end

  task :tags, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting Tags..."
    count = 0

    db.execute("SELECT * FROM Tag").each do |row|
      Tag.create!(id: row["id"], name: row["name"])
      count += 1
    end

    reset_pk_sequence("tags")
    puts "  Imported #{count} tags"
  end

  task :companies, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting Companies..."
    count = 0

    db.execute("SELECT * FROM Company").each do |row|
      Company.create!(
        id: row["id"],
        name: row["name"],
        alias: row["alias"],
        active: row["active"] == 1,
        is_customer: row["isCustomer"] == 1,
        is_partner: row["isPartner"] == 1,
        website: row["website"],
        image_url: row["imageUrl"],
        notes: row["notes"],
        city: row["city"],
        state: row["state"],
        country: row["country"],
        build_level: row["buildLevel"],
        consulting_level: row["consultingLevel"],
        reseller_level: row["resellerLevel"],
        service_provider_level: row["serviceProviderLevel"],
        partner_level: row["partnerLevel"],
        servicenow_url: row["serviceNowUrl"],
        rss_feed_url: row["rssFeedUrl"],
        servicenow_page_url: row["serviceNowPageUrl"],
        products: row["products"],
        services: row["services"],
        last_fetched_at: row["lastFetchedAt"],
        last_sitemap_check: row["lastSitemapCheck"],
        has_sitemap: row["hasSitemap"] == 1,
        last_found_in_partner_list: row["lastFoundInPartnerList"],
        locked_fields: row["lockedFields"],
        created_at: row["createdAt"],
        updated_at: row["updatedAt"] || Time.current
      )
      count += 1
    end

    reset_pk_sequence("companies")
    puts "  Imported #{count} companies"
  end

  task :news_feeds, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting NewsFeeds..."
    count = 0

    db.execute("SELECT * FROM NewsFeed").each do |row|
      NewsFeed.create!(
        id: row["id"],
        title: row["title"],
        active: row["active"] == 1,
        status: row["status"] || "active",
        notes: row["notes"],
        image_url: row["imageUrl"],
        url: row["url"],
        default_author: row["defaultAuthor"],
        feed_type: row["type"] || "rss",
        fetch_url: row["fetchUrl"],
        last_successful_fetch: row["lastSuccessfulFetch"],
        last_error: row["lastError"],
        error_count: row["errorCount"] || 0,
        created_at: row["createdAt"],
        updated_at: row["updatedAt"] || Time.current
      )
      count += 1
    end

    reset_pk_sequence("news_feeds")
    puts "  Imported #{count} news feeds"
  end

  task :participants, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting Participants..."
    count = 0

    db.execute("SELECT * FROM Participant").each do |row|
      Participant.create!(
        id: row["id"],
        name: row["name"],
        alias: row["alias"],
        company_name: row["company"],
        title: row["title"],
        bio: row["bio"],
        image_url: row["imageUrl"],
        linkedin_url: row["linkedInUrl"],
        user_id: row["userId"],
        company_id: row["companyId"],
        created_at: row["createdAt"],
        updated_at: Time.current
      )
      count += 1
    end

    reset_pk_sequence("participants")
    puts "  Imported #{count} participants"
  end

  task :news_items, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting NewsItems..."
    count = 0
    errors = 0

    db.execute("SELECT * FROM NewsItem").each do |row|
      begin
        NewsItem.create!(
          id: row["id"],
          item_type: row["type"] || "article",
          active: row["active"] == 1,
          state: row["state"] || "new",
          title: row["title"],
          body: row["body"],
          url: row["url"],
          image_url: row["imageUrl"],
          duration: row["duration"],
          published_at: row["publishedAt"],
          event_start: row["eventStart"],
          event_end: row["eventEnd"],
          event_location: row["eventLocation"],
          ad_url: row["adUrl"],
          call_to_action: row["callToAction"],
          news_feed_id: row["newsFeedId"],
          created_at: row["createdAt"],
          updated_at: row["updatedAt"] || Time.current
        )
        count += 1
      rescue => e
        errors += 1
        # Skip duplicates silently
      end

      print "\r  Imported #{count} news items (#{errors} errors)" if count % 1000 == 0
    end

    reset_pk_sequence("news_items")
    puts "\r  Imported #{count} news items (#{errors} errors)"
  end

  task :news_item_participants, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting NewsItemParticipants..."
    count = 0

    db.execute("SELECT * FROM NewsItemParticipant").each do |row|
      begin
        NewsItemParticipant.create!(
          id: row["id"],
          news_item_id: row["newsItemId"],
          participant_id: row["participantId"],
          created_at: row["createdAt"]
        )
        count += 1
      rescue => e
        # Skip invalid references
      end
    end

    reset_pk_sequence("news_item_participants")
    puts "  Imported #{count} news item participants"
  end

  task :news_item_tags, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting NewsItemTags..."
    count = 0

    db.execute("SELECT * FROM NewsItemTag").each do |row|
      begin
        NewsItemTag.create!(
          id: row["id"],
          news_item_id: row["newsItemId"],
          tag_id: row["tagId"]
        )
        count += 1
      rescue => e
        # Skip invalid references
      end
    end

    reset_pk_sequence("news_item_tags")
    puts "  Imported #{count} news item tags"
  end

  task :knowledge_sessions, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting KnowledgeSessions..."
    count = 0

    db.execute("SELECT * FROM KnowledgeSession").each do |row|
      KnowledgeSession.create!(
        id: row["id"],
        code: row["code"],
        session_id: row["sessionId"],
        title: row["title"],
        title_sort: row["title_sort"],
        abstract: row["abstract"],
        published: row["published"],
        modified: row["modified"],
        event_id: row["eventId"],
        participants: row["participants"],
        times: row["times"],
        recording_url: row["recordingUrl"],
        created_at: row["createdAt"],
        updated_at: row["updatedAt"] || Time.current
      )
      count += 1
    end

    reset_pk_sequence("knowledge_sessions")
    puts "  Imported #{count} knowledge sessions"
  end

  task :knowledge_session_participants, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting KnowledgeSessionParticipants..."
    count = 0

    db.execute("SELECT * FROM KnowledgeSessionParticipant").each do |row|
      begin
        KnowledgeSessionParticipant.create!(
          id: row["id"],
          knowledge_session_id: row["knowledgeSessionId"],
          participant_id: row["participantId"],
          created_at: row["createdAt"]
        )
        count += 1
      rescue => e
        # Skip invalid references
      end
    end

    reset_pk_sequence("knowledge_session_participants")
    puts "  Imported #{count} knowledge session participants"
  end

  task :knowledge_session_lists, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting KnowledgeSessionLists..."
    count = 0

    db.execute("SELECT * FROM KnowledgeSessionList").each do |row|
      begin
        KnowledgeSessionList.create!(
          id: row["id"],
          knowledge_session_id: row["knowledgeSessionId"],
          user_id: row["userId"],
          created_at: row["createdAt"],
          updated_at: row["updatedAt"] || Time.current
        )
        count += 1
      rescue => e
        # Skip invalid references
      end
    end

    reset_pk_sequence("knowledge_session_lists")
    puts "  Imported #{count} knowledge session lists"
  end

  task :servicenow_store_apps, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting ServicenowStoreApps..."
    count = 0

    db.execute("SELECT * FROM ServiceNowStoreApp").each do |row|
      ServicenowStoreApp.create!(
        id: row["id"],
        source_app_id: row["sourceAppId"],
        title: row["title"],
        tagline: row["tagline"],
        store_description: row["storeDescription"],
        company_name: row["companyName"],
        company_logo: row["companyLogo"],
        logo: row["logo"],
        app_type: row["appType"],
        app_sub_type: row["appSubType"],
        version: row["version"],
        versions_data: row["versionsData"],
        purchase_count: row["purchaseCount"],
        review_count: row["reviewCount"],
        table_count: row["tableCount"],
        key_features: row["keyFeatures"],
        business_challenge: row["businessChallenge"],
        system_requirements: row["systemRequirements"],
        supporting_media: row["supportingMedia"],
        support_links: row["supportLinks"],
        support_contacts: row["supportContacts"],
        purchase_trend: row["purchaseTrend"],
        display_price: row["displayPrice"],
        landing_page: row["landingPage"],
        allow_for_existing_customers: row["allowForExistingCustomers"] == 1,
        allow_for_non_customers: row["allowForNonCustomers"] == 1,
        allow_on_customer_subprod: row["allowOnCustomerSubprod"] == 1,
        allow_on_developer_instance: row["allowOnDeveloperInstance"] == 1,
        allow_on_servicenow_instance: row["allowOnServiceNowInstance"] == 1,
        allow_trial: row["allowTrial"] == 1,
        allow_without_license: row["allowWithoutLicense"] == 1,
        last_fetched_at: row["lastFetchedAt"],
        published_at: row["publishedAt"],
        created_at: row["createdAt"],
        updated_at: Time.current
      )
      count += 1
    end

    reset_pk_sequence("servicenow_store_apps")
    puts "  Imported #{count} store apps"
  end

  task :servicenow_investments, [ :db ] => :environment do |t, args|
    db = args[:db]
    puts "\nImporting ServicenowInvestments..."
    count = 0

    db.execute("SELECT * FROM ServiceNowInvestment").each do |row|
      ServicenowInvestment.create!(
        id: row["id"],
        investment_type: row["type"],
        content: row["content"],
        summary: row["summary"],
        url: row["url"],
        amount: row["amount"],
        currency: row["currency"],
        date: row["date"],
        people: row["people"],
        company_name: row["company"],
        created_at: row["createdAt"],
        updated_at: row["updatedAt"] || Time.current
      )
      count += 1
    end

    reset_pk_sequence("servicenow_investments")
    puts "  Imported #{count} investments"
  end

  private

  def reset_pk_sequence(table_name)
    # SQLite handles auto-increment differently, but we need to ensure
    # the next ID is greater than the max imported ID
    max_id = ActiveRecord::Base.connection.execute("SELECT MAX(id) FROM #{table_name}").first[0]
    if max_id
      ActiveRecord::Base.connection.execute("UPDATE sqlite_sequence SET seq = #{max_id} WHERE name = '#{table_name}'")
    end
  end
end
