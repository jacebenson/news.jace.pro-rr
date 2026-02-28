#!/usr/bin/env ruby
# frozen_string_literal: true

# Update MVP awards with source URLs
# Usage: bin/rails runner scripts/update_mvp_sources.rb

require 'csv'

puts "Starting MVP source URL update..."

# Read source URLs from Sources CSV
sources_csv_path = Rails.root.join("MVP's So Far_ - Sources.csv")
sources = {}

if File.exist?(sources_csv_path)
  CSV.foreach(sources_csv_path, headers: true) do |row|
    year = row['Year']&.strip
    award = row['Award']&.strip
    source_url = row['Source']&.strip

    if year && award && source_url.present?
      sources["#{year}-#{award}"] = source_url
    end
  end
  puts "Loaded #{sources.size} source URLs"
else
  puts "Error: Sources CSV not found at #{sources_csv_path}"
  exit 1
end

# Award type mapping
award_type_mapping = {
  "Community MVP" => "Top Contributor Program",
  "Rising Star" => "Top Contributor Program",  # 2022-2023 Rising Stars are in Top Contributor announcement
  "Most Valuable Professional" => "Top Contributor Program"  # 2024-2025 MVPs are in Top Contributor announcement
}

updated = 0
skipped = 0

MvpAward.where(source_url: [ nil, "" ]).find_each do |award|
  # Map award type for source lookup
  lookup_award = award_type_mapping[award.award_type] || award.award_type
  source_key = "#{award.year}-#{lookup_award}"
  source_url = sources[source_key]

  # Special case for 2026 which has a typo in the source CSV
  if source_url.blank? && award.year == 2026 && award.award_type == "Most Valuable Professional"
    source_key = "2026-Most Valued Profesionals"
    source_url = sources[source_key]
  end

  if source_url.present?
    award.update!(source_url: source_url)
    updated += 1
    puts "Updated: #{award.participant.name} - #{award.award_type} #{award.year}"
  else
    skipped += 1
  end
end

puts "\n=== Update Complete ==="
puts "Updated: #{updated}"
puts "Skipped (no source available): #{skipped}"
puts "Awards with sources: #{MvpAward.where.not(source_url: [ nil, '' ]).count}"
puts "Awards without sources: #{MvpAward.where(source_url: [ nil, '' ]).count}"
