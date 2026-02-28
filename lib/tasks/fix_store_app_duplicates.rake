# lib/tasks/fix_store_app_duplicates.rake
#
# Run with: bin/rails fix_duplicates:all
#
# This task fixes duplicate ServiceNow Store Apps that have the same title
# but different source_app_ids. This happens when:
# 1. Old records stored listing_id in source_app_id field
# 2. Full fetch creates new records with correct source_app_id
#
# The task:
# 1. Finds duplicates where one has listing_id (good) and one doesn't (old)
# 2. Merges purchase_trend data from old -> good
# 3. Deletes old record
# 4. Finds true duplicates (same company, same version)
# 5. Keeps the one with most trend history

namespace :fix_duplicates do
  desc "Fix all store app duplicates by merging trend data and removing old records"
  task all: :environment do
    puts "=" * 60
    puts "STORE APP DUPLICATE FIX"
    puts "=" * 60

    # Step 1: Find duplicates with one good (has listing_id) and one old
    puts "\n[Step 1] Finding duplicates with one good record..."

    results = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT title, COUNT(*) as cnt#{' '}
      FROM servicenow_store_apps#{' '}
      GROUP BY title#{' '}
      HAVING COUNT(*) > 1
    SQL

    good_old_pairs = []
    true_duplicates = []
    different_apps = []

    results.each do |row|
      title = row["title"]
      apps = ServicenowStoreApp.where(title: title).order(:created_at)

      with_listing = apps.select { |a| a.listing_id.present? }
      without_listing = apps.select { |a| a.listing_id.blank? }

      if with_listing.any? && without_listing.any?
        good_old_pairs << { title: title, good: with_listing.first, old: without_listing }
      elsif apps.count > 1
        # Check if same company and version (true duplicates)
        groups = apps.group_by { |a| [ a.company_name, a.version ] }
        if groups.keys.count == 1
          true_duplicates << { title: title, apps: apps.to_a }
        else
          different_apps << { title: title, apps: apps.to_a }
        end
      end
    end

    puts "  Found #{good_old_pairs.count} pairs to merge (one good, one old)"
    puts "  Found #{true_duplicates.count} true duplicates (same company/version)"
    puts "  Found #{different_apps.count} different apps with same title (keeping both)"

    # Step 2: Merge good/old pairs
    puts "\n[Step 2] Merging good/old pairs..."

    good_old_pairs.each do |pair|
      good = pair[:good]
      pair[:old].each do |old|
        merge_and_delete(good, old)
      end
    end

    # Step 3: Merge true duplicates (keep the one with most trend history)
    puts "\n[Step 3] Merging true duplicates..."

    true_duplicates.each do |dup|
      apps = dup[:apps].sort_by do |a|
        trend = JSON.parse(a.purchase_trend || "{}") rescue {}
        -trend.keys.count # Descending
      end

      keep = apps.first
      apps[1..].each do |delete_app|
        merge_and_delete(keep, delete_app)
      end
    end

    # Step 4: Run full fetch to populate listing_id
    puts "\n[Step 4] Summary"
    puts "  Total apps: #{ServicenowStoreApp.count}"
    puts "  With listing_id: #{ServicenowStoreApp.where.not(listing_id: [ nil, '' ]).count}"
    puts "  Missing listing_id: #{ServicenowStoreApp.where(listing_id: [ nil, '' ]).count}"

    remaining = ActiveRecord::Base.connection.execute(<<~SQL).first["cnt"]
      SELECT COUNT(*) as cnt FROM (
        SELECT title FROM servicenow_store_apps GROUP BY title HAVING COUNT(*) > 1
      )
    SQL
    puts "  Remaining duplicate titles: #{remaining}"

    puts "\n[Done] Duplicate fix complete!"
    puts "\nNext: Run FetchAppsJob.perform_now to populate listing_id on remaining apps"
  end

  desc "Run full fetch to populate listing_id"
  task fetch: :environment do
    puts "Running FetchAppsJob..."
    puts "This will take ~1 hour (3000+ apps with 1s delay each)"
    FetchAppsJob.perform_now
    puts "Done!"
  end

  desc "Show current duplicate stats"
  task stats: :environment do
    puts "=" * 60
    puts "STORE APP STATS"
    puts "=" * 60

    puts "\nTotal apps: #{ServicenowStoreApp.count}"
    puts "With listing_id: #{ServicenowStoreApp.where.not(listing_id: [ nil, '' ]).count}"
    puts "Missing listing_id: #{ServicenowStoreApp.where(listing_id: [ nil, '' ]).count}"

    results = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT title, COUNT(*) as cnt#{' '}
      FROM servicenow_store_apps#{' '}
      GROUP BY title#{' '}
      HAVING COUNT(*) > 1
    SQL

    puts "\nDuplicate titles: #{results.count}"

    if results.count > 0
      puts "\nDuplicates:"
      results.each do |row|
        title = row["title"]
        apps = ServicenowStoreApp.where(title: title).order(:id)

        puts "\n  \"#{title.to_s.truncate(50)}\""
        apps.each do |app|
          has_listing = app.listing_id.present? ? "✓" : "✗"
          trend_count = JSON.parse(app.purchase_trend || "{}").keys.count rescue 0
          puts "    ID #{app.id}: v#{app.version || '?'} | #{app.company_name&.truncate(20) || '?'} | #{trend_count} trend | [#{has_listing}]"
        end
      end
    end
  end

  private

  def merge_and_delete(keep, delete_app)
    return if keep.id == delete_app.id

    keep_trend = JSON.parse(keep.purchase_trend || "{}") rescue {}
    delete_trend = JSON.parse(delete_app.purchase_trend || "{}") rescue {}

    # Merge trends (keep takes precedence for same dates)
    merged = delete_trend.merge(keep_trend)

    # Copy listing_id/source_app_id if keep doesn't have them
    if delete_app.listing_id.present? && keep.listing_id.blank?
      keep.listing_id = delete_app.listing_id
    end
    if delete_app.source_app_id.present? && keep.source_app_id.blank?
      keep.source_app_id = delete_app.source_app_id
    end

    keep.purchase_trend = merged.to_json
    keep.save!

    puts "  Merged \"#{keep.title.to_s.truncate(40)}\": kept ID #{keep.id}, deleted ID #{delete_app.id} (#{delete_trend.keys.count} -> #{merged.keys.count} trend entries)"

    delete_app.destroy!
  rescue => e
    puts "  ERROR merging #{keep.id}/#{delete_app.id}: #{e.message}"
  end
end

# Make private method available at module level
def merge_and_delete(keep, delete_app)
  return if keep.id == delete_app.id

  keep_trend = JSON.parse(keep.purchase_trend || "{}") rescue {}
  delete_trend = JSON.parse(delete_app.purchase_trend || "{}") rescue {}

  merged = delete_trend.merge(keep_trend)

  if delete_app.listing_id.present? && keep.listing_id.blank?
    keep.listing_id = delete_app.listing_id
  end
  if delete_app.source_app_id.present? && keep.source_app_id.blank?
    keep.source_app_id = delete_app.source_app_id
  end

  keep.purchase_trend = merged.to_json
  keep.save!

  puts "  Merged \"#{keep.title.to_s.truncate(40)}\": kept ID #{keep.id}, deleted ID #{delete_app.id} (#{delete_trend.keys.count} -> #{merged.keys.count} trend entries)"

  delete_app.destroy!
rescue => e
  puts "  ERROR merging #{keep.id}/#{delete_app.id}: #{e.message}"
end
