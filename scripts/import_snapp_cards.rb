#!/usr/bin/env ruby
# frozen_string_literal: true

# Import Snapp cards from JavaScript data
# Usage: bin/rails runner scripts/import_snapp_cards.rb

puts "Starting Snapp cards import..."

# Snapp card data from the original JS file
snapp_data = [
  { fullName: 'Bill McDermott', edition: "Snapp '24", card: 'Bill from the Deli' },
  { fullName: 'Brad Tilton', edition: "Snapp '24", card: 'Brad the Beard' },
  { fullName: 'Corey CJ Wesley', edition: "Snapp '24", card: 'Captain CJ' },
  { fullName: 'Robert Fedoruk', edition: "Snapp '24", card: 'The Duke' },
  { fullName: 'Earl Duque', edition: "Snapp '24", card: 'The Earl' },
  { fullName: 'Andrew Albury-Dor', edition: "Snapp '24", card: 'The Fladvocado' },
  { fullName: 'Fred Luddy', edition: "Snapp '24", card: 'Fred the Founder' },
  { fullName: 'Chuck Tomasi', edition: "Snapp '24", card: 'Iron Chuck' },
  { fullName: 'Jelly Script', edition: "Snapp '24", card: 'Jelly Script' },
  { fullName: 'LiquorBot', edition: "Snapp '24", card: 'LiquorBot' },
  { fullName: 'Jason McKee', edition: "Snapp '24", card: 'Maker McKee' },
  { fullName: 'Mark Stanger', edition: "Snapp '24", card: 'Mark the Stranger' },
  { fullName: 'Lauren McManamon', edition: "Snapp '24", card: 'MechManamon' },
  { fullName: 'Maria Waechter', edition: "Snapp '24", card: 'Mega POW' },
  { fullName: 'Dave Wright', edition: "Snapp '24", card: 'Mr Wright' },
  { fullName: 'The NextGens', edition: "Snapp '24", card: 'The NextGens' },
  { fullName: 'Tim Woodruff', edition: "Snapp '24", card: 'The Professor' },
  { fullName: 'Michael Lombardo', edition: "Snapp '24", card: 'The Mayor' },
  { fullName: 'Arnoud Kooi', edition: "Snapp '24", card: 'The Toolmaker' },
  { fullName: 'Travis Toulson', edition: "Snapp '24", card: 'The Toulsons - Portal Explorers' },
  { fullName: 'Sarah Toulson', edition: "Snapp '24", card: 'The Toulsons - Portal Explorers' },
  { fullName: 'Goran Lundqvist', edition: "Snapp '24", card: 'the Witchdoctor' },
  { fullName: 'Andrew Barnes', edition: "Snapp '24x", card: 'Rightside-up Andrew' },
  { fullName: 'Robert Fedoruk', edition: "Snapp '24x", card: 'Dual-Wield Duke' },
  { fullName: 'Pranav Bhagat', edition: "Snapp '24x", card: 'Pranav Bot' },
  { fullName: 'Kristy Merriam', edition: "Snapp '24x", card: 'The Rookie' },
  { fullName: 'Ty Roach', edition: "Snapp '24x", card: 'The List Checker' },
  { fullName: 'Jace Benson', edition: "Snapp '24x", card: 'The Newsman' },
  { fullName: 'Kali Alexander', edition: "Snapp '24x", card: 'Queen Kali' },
  { fullName: 'Paul Morris', edition: "Snapp '24x", card: 'The Nerd' },
  { fullName: 'Casey Ferguson', edition: "Snapp '24x", card: 'Veolcity' },
  { fullName: 'Pat Casey', edition: "Snapp '24x", card: 'The Architect' },
  { fullName: 'Maik Skoddow', edition: "Snapp '24x", card: 'The Shaddow' },
  { fullName: 'Ankur Bawiskar', edition: "Snapp '24x", card: 'Mr Everywhere' },
  { fullName: 'Mark Roethof', edition: "Snapp '24x", card: 'The Test Master' },
  { fullName: 'Astrid Sapphire', edition: "Snapp '24x", card: 'Astral' },
  { fullName: 'Mark Bodman', edition: "Snapp '24x", card: 'The Modeller' },
  { fullName: 'Idris Elba', edition: "Snapp '24x", card: 'The Ambassador' },
  { fullName: 'Dave Slusher', edition: "Snapp '24x", card: 'The Evil Genius' },
  { fullName: 'Carleen Carter', edition: "Snapp '24x", card: 'Captain Carter' },
  { fullName: 'James Neale', edition: "Snapp '24x", card: 'The Xplorer' },
  { fullName: 'K14 NowGuys', edition: "Snapp '24x", card: 'The NowGuys' },
  { fullName: 'Nathan Firth', edition: "Snapp '24x", card: 'The Portal Engineer' }
]

imported = 0
skipped = 0
errors = []

snapp_data.each do |data|
  person = data[:fullName]
  edition = data[:edition]
  card_name = data[:card]

  begin
    # Find or create participant
    participant = Participant.find_or_create_by!(name: person) do |p|
      puts "Created new participant: #{person}"
    end

    # Create Snapp card (idempotent - will skip if already exists due to unique index)
    card = SnappCard.find_or_initialize_by(
      participant: participant,
      edition: edition,
      card_name: card_name
    )

    if card.new_record?
      card.save!
      imported += 1
      puts "Imported: #{person} - #{card_name} (#{edition})"
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
puts "Total Snapp Cards: #{SnappCard.count}"
puts "Participants with Snapp Cards: #{Participant.with_snapp_cards.count}"
puts "Cards by Edition:"
SnappCard.group(:edition).count.each do |edition, count|
  puts "  - #{edition}: #{count}"
end
