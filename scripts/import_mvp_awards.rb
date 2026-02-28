#!/usr/bin/env ruby
# frozen_string_literal: true

# Import MVP awards from CSV files
# Usage: bin/rails runner scripts/import_mvp_awards.rb

require 'csv'

puts "Starting MVP awards import..."

# Read source URLs from Sources CSV
sources_csv_path = Rails.root.join("MVP's So Far_ - Sources.csv")
sources = {}

if File.exist?(sources_csv_path)
  CSV.foreach(sources_csv_path, headers: true) do |row|
    year = row['Year']&.strip
    award = row['Award']&.strip
    source_url = row['Source']&.strip

    if year && award
      sources["#{year}-#{award}"] = source_url
    end
  end
  puts "Loaded #{sources.size} source URLs"
else
  puts "Warning: Sources CSV not found at #{sources_csv_path}"
end

# Read and process MVP data
data_csv_path = Rails.root.join("MVP's So Far_ - Data.csv")

unless File.exist?(data_csv_path)
  puts "Error: Data CSV not found at #{data_csv_path}"
  exit 1
end

imported = 0
skipped = 0
errors = []

CSV.foreach(data_csv_path, headers: true) do |row|
  person = row['Person']&.strip
  year = row['Year']&.strip
  award = row['Award']&.strip

  # Skip if missing required data
  if person.blank? || year.blank? || award.blank?
    puts "Skipping row with missing data: #{row.inspect}"
    skipped += 1
    next
  end

  year_int = year.to_i
  if year_int == 0
    puts "Invalid year for #{person}: #{year}"
    skipped += 1
    next
  end

  begin
    # Find or create participant
    participant = Participant.find_or_create_by!(name: person) do |p|
      puts "Created new participant: #{person}"
    end

    # Look up source URL
    # Map "Community MVP" to "Top Contributor Program" for source lookup
    # since sources use different naming than the data
    source_lookup_award = case award
    when "Community MVP"
                            "Top Contributor Program"
    when "Most Valuable Professional"
                            "Most Valued Profesionals"  # Note: typo in source CSV
    else
                            award
    end
    source_key = "#{year}-#{source_lookup_award}"
    source_url = sources[source_key]

    # Create MVP award (idempotent - will skip if already exists due to unique index)
    award_record = MvpAward.find_or_initialize_by(
      participant: participant,
      year: year_int,
      award_type: award
    )

    if award_record.new_record?
      award_record.source_url = source_url
      award_record.save!
      imported += 1
      puts "Imported: #{person} - #{award} #{year}"
    else
      skipped += 1
    end

  rescue ActiveRecord::RecordInvalid => e
    errors << "#{person}: #{e.message}"
    puts "Error importing #{person}: #{e.message}"
  rescue StandardError => e
    errors << "#{person}: #{e.message}"
    puts "Error importing #{person}: #{e.message}"
  end
end

puts "\n=== Import Complete ==="
puts "Imported: #{imported}"
puts "Skipped (already exists): #{skipped}"
puts "Errors: #{errors.size}"

if errors.any?
  puts "\nErrors encountered:"
  errors.each { |e| puts "  - #{e}" }
end

# Display statistics
puts "\n=== Statistics ==="
puts "Total MVP Awards: #{MvpAward.count}"
puts "Participants with MVP Awards: #{Participant.with_mvp_awards.count}"
puts "Award Types:"
MvpAward.group(:award_type).count.sort_by { |_, count| -count }.each do |award_type, count|
  puts "  - #{award_type}: #{count}"
end
puts "Awards by Year:"
MvpAward.group(:year).count.sort.each do |year, count|
  puts "  - #{year}: #{count}"
end
