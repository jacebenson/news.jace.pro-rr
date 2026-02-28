#!/usr/bin/env ruby
# frozen_string_literal: true

# Import Startup founders from JavaScript data
# Usage: bin/rails runner scripts/import_startup_founders.rb

puts "Starting Startup founders import..."

# Startup founder data from the original JS file
startup_data = [
  { fullName: 'Christopher Shutts', companies: [ 'Logik.ai' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-logik-ai.html' },
  { fullName: 'Fazal Gupta', companies: [ 'Logik.ai' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-logik-ai.html' },
  { fullName: 'Godard Abel', companies: [ 'Logik.ai' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-logik-ai.html' },
  { fullName: 'Bhavin Shah', companies: [ 'Moveworks' ], source: 'https://techcrunch.com/2025/03/10/servicenow-buys-moveworks-for-2-85b-to-grow-its-ai-portfolio/' },
  { fullName: 'Vaibhav Nivargi', companies: [ 'Moveworks' ], source: 'https://techcrunch.com/2025/03/10/servicenow-buys-moveworks-for-2-85b-to-grow-its-ai-portfolio/' },
  { fullName: 'Varun Singh', companies: [ 'Moveworks' ], source: 'https://techcrunch.com/2025/03/10/servicenow-buys-moveworks-for-2-85b-to-grow-its-ai-portfolio/' },
  { fullName: 'Jiang Chen', companies: [ 'Moveworks' ], source: 'https://techcrunch.com/2025/03/10/servicenow-buys-moveworks-for-2-85b-to-grow-its-ai-portfolio/' },
  { fullName: 'Elliot West', companies: [ 'Advania(Quality360)' ], source: 'https://www.servicenow.com/company/media/press-room/acquires-advania-quality-360.html' },
  { fullName: 'Mayukh Bhaowal', companies: [ 'CueIn' ], source: 'https://www.crn.com/news/channel-news/2025/servicenow-plans-cuein-acquisition-to-expand-agentic-ai-roadmap?utm_source=jace.pro&utm_medium=referral&utm_campaign=servicenow-keeps-buying-things' },
  { fullName: 'Vignesh Ganapathy', companies: [ 'CueIn' ], source: 'https://www.crn.com/news/channel-news/2025/servicenow-plans-cuein-acquisition-to-expand-agentic-ai-roadmap?utm_source=jace.pro&utm_medium=referral&utm_campaign=servicenow-keeps-buying-things' },
  { fullName: 'Daniel P.', companies: [ 'Mission Secure' ], source: 'https://www.servicenow.com/blogs/2024/mission-secure-enhance-ot-asset-visibility' },
  { fullName: 'Rick A. Jones, Ph.D', companies: [ 'Mission Secure' ], source: 'https://www.servicenow.com/blogs/2024/mission-secure-enhance-ot-asset-visibility' },
  { fullName: 'Valentin Richter', companies: [ 'Raytion' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-acquires-raytion.html' },
  { fullName: 'Luc Raeskin', companies: [ '4Industry' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-4industry-ey.html' },
  { fullName: 'Elmer de Valk', companies: [ '4Industry' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-4industry-ey.html' },
  { fullName: 'Efi Levi', companies: [ "Atrinet's (NETAce Product)" ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-atrinet.html' },
  { fullName: 'Robert Samanek', companies: [ 'UltimateSuite' ], source: 'https://www.servicenow.com/content/servicenow/www/locale-sites/en-us/company/media/press-room/servicenow-to-acquire-ultimatesuite.html' },
  { fullName: 'Karsten Neugebauer', companies: [ 'G2K' ], source: '' },
  { fullName: 'Omar El Gohary', companies: [ 'G2K' ], source: '' },
  { fullName: 'Todd Persen', companies: [ 'Era Software' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-era-software.html' },
  { fullName: 'Heather Jerrehian', companies: [ 'Hitch Works Inc.' ], source: '' },
  { fullName: 'Kelley Steven-Waiss', companies: [ 'Hitch Works Inc.' ], source: '' },
  { fullName: 'Jared Laethem', companies: [ 'Dotwalk.io' ], source: 'https://www.servicenow.com/blogs/2021/acquires-dotwalk-automates-upgrade-testing.html' },
  { fullName: 'Jens Strandbygaard', companies: [ 'Gekkobrain' ], source: 'https://www.servicenow.com/blogs/2021/gekkobrain-acquisition-erp-migrations.html' },
  { fullName: 'Médéric Morel', companies: [ 'Mapwize' ], source: 'https://www.servicenow.com/company/media/press-room/servicenow-to-acquire-mapwize.html' },
  { fullName: 'Thomas Richter', companies: [ 'Swarm64' ], source: '' },
  { fullName: 'Eivind Liland', companies: [ 'Swarm64' ], source: '' },
  { fullName: 'Alfonso Martinez', companies: [ 'Swarm64' ], source: '' },
  { fullName: 'Ben Sigelman', companies: [ 'Lightstep' ], source: '' },
  { fullName: 'Daniel Spoonhower', companies: [ 'Lightstep' ], source: '' },
  { fullName: 'Alekh Barli', companies: [ 'Intellibot' ], source: '' },
  { fullName: 'Srikanth Vemulapalli', companies: [ 'Intellibot' ], source: '' },
  { fullName: 'Kushang Moorthy', companies: [ 'Intellibot' ], source: '' },
  { fullName: 'Yoshua Bengio', companies: [ 'Element AI' ], source: '' },
  { fullName: 'Anne Martel', companies: [ 'Element AI' ], source: '' },
  { fullName: 'Nicolas Chapados', companies: [ 'Element AI' ], source: '' },
  { fullName: 'Philippe Beaudoin', companies: [ 'Element AI' ], source: '' },
  { fullName: 'Jean-François Gagné', companies: [ 'Element AI' ], source: '' },
  { fullName: 'Jean-Sébastien Cournoye', companies: [ 'Element AI' ], source: '' },
  { fullName: 'Mark Verstockt', companies: [ 'Sweagle' ], source: '' },
  { fullName: 'Benny Van de Sompele', companies: [ 'Sweagle' ], source: '' },
  { fullName: 'Ravi N. Raj', companies: [ 'Passage AI' ], source: '' },
  { fullName: 'Madhu Mathihalli', companies: [ 'Passage AI' ], source: '' },
  { fullName: 'Mitul Tiwari', companies: [ 'Passage AI' ], source: '' },
  { fullName: 'Ronny Lehmann', companies: [ 'Loom Systems' ], source: '' },
  { fullName: 'Gabby Menachem', companies: [ 'Loom Systems' ], source: '' },
  { fullName: 'Dror Mann', companies: [ 'Loom Systems' ], source: '' },
  { fullName: 'Aaron Callaway', companies: [ 'Fairchild' ], source: '' },
  { fullName: 'Ali Riaz', companies: [ 'Attivio' ], source: '' },
  { fullName: 'Sid Probstein', companies: [ 'Attivio' ], source: '' },
  { fullName: 'Will Johnson', companies: [ 'Attivio' ], source: '' },
  { fullName: 'Zahi Boussiba', companies: [ 'Appsee' ], source: '' },
  { fullName: 'Yoni Douek', companies: [ 'Appsee' ], source: '' },
  { fullName: 'Michael Rumiantsau', companies: [ 'FriendlyData' ], source: '' },
  { fullName: 'Alex Zaytsav', companies: [ 'FriendlyData' ], source: '' },
  { fullName: 'Alexey Zenovich', companies: [ 'FriendlyData' ], source: '' },
  { fullName: 'Murali Subbarao', companies: [ 'Parlo' ], source: '' },
  { fullName: 'Ben Stephens', companies: [ 'VendorHawk' ], source: '' },
  { fullName: 'Brian Geihsler', companies: [ 'VendorHawk' ], source: '' },
  { fullName: 'Patrick Lowndes', companies: [ 'VendorHawk' ], source: '' },
  { fullName: 'Boaz Hecht', companies: [ 'SkyGiraffe' ], source: '' },
  { fullName: 'Itay Braun', companies: [ 'SkyGiraffe' ], source: '' },
  { fullName: 'Takahito (Taka) Iguchi', companies: [ 'Telepathy' ], source: '' },
  { fullName: 'Rahim Yaseen', companies: [ 'Qlue' ], source: '' },
  { fullName: 'Baskar Jayaraman', companies: [ 'DxContinuum' ], source: '' },
  { fullName: 'Debu Chatterjee', companies: [ 'DxContinuum' ], source: '' },
  { fullName: 'Kannan Govindarajan', companies: [ 'DxContinuum' ], source: '' },
  { fullName: 'Robert Laikin', companies: [ 'BrightPoint' ], source: '' },
  { fullName: 'Andrew Tahvildary', companies: [ 'ITApp' ], source: '' },
  { fullName: 'Brajesh Goyal', companies: [ 'ITApp' ], source: '' },
  { fullName: 'Brian Krug', companies: [ 'ITApp' ], source: '' },
  { fullName: 'Giri Padmanabh', companies: [ 'ITApp' ], source: '' },
  { fullName: 'Kristopher Markham', companies: [ 'Intreis' ], source: '' },
  { fullName: 'Morgan Hunter', companies: [ 'Intreis' ], source: '' },
  { fullName: 'Yuval Cohen', companies: [ 'Neebula Systems' ], source: '' },
  { fullName: 'Ariel Gordon', companies: [ 'Neebula Systems' ], source: '' },
  { fullName: 'Shai Mohaban', companies: [ 'Neebula Systems' ], source: '' },
  { fullName: 'Karel van der Poel', companies: [ 'Mirror42' ], source: '' }
]

imported = 0
skipped = 0
errors = []

startup_data.each do |data|
  person = data[:fullName]
  companies = data[:companies]
  source_url = data[:source]

  begin
    # Find or create participant
    participant = Participant.find_or_create_by!(name: person) do |p|
      puts "Created new participant: #{person}"
    end

    # Create a founder record for each company
    companies.each do |company_name|
      founder = StartupFounder.find_or_initialize_by(
        participant: participant,
        company_name: company_name
      )

      if founder.new_record?
        founder.source_url = source_url if source_url.present?
        founder.save!
        imported += 1
        puts "Imported: #{person} - #{company_name}"
      else
        skipped += 1
      end
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
puts "Total Startup Founder Records: #{StartupFounder.count}"
puts "Unique Startup Founders: #{Participant.with_startup_founders.count}"
puts "Top Companies by Founder Count:"
StartupFounder.group(:company_name).count.sort_by { |_, count| -count }.first(10).each do |company, count|
  puts "  - #{company}: #{count}"
end
