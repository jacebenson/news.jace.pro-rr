class LinkParticipantsJob < ApplicationJob
  queue_as :default

  # Links Participants to Companies by matching company names
  #
  # Matching strategies:
  # 1. Exact match (case-insensitive)
  # 2. Prefix match (participant "Deloitte" matches company "Deloitte Consulting LLP")
  # 3. Reverse prefix (company "IBM" matches participant "IBM Corporation")

  def perform
    Rails.logger.info "[LINK] Starting LinkParticipantsJob"
    job_start = Time.current

    # Get all companies for matching
    companies = Company.all.pluck(:id, :name, :is_customer, :is_partner)
    Rails.logger.info "[LINK] Loaded #{companies.length} companies for matching"

    # Build lookup maps
    exact_match = {}
    company_list = companies.map do |id, name, is_customer, is_partner|
      record = { id: id, name: name, is_customer: is_customer, is_partner: is_partner, name_lower: name.downcase }
      exact_match[record[:name_lower]] = record
      record
    end

    # Get participants without a company_id who have a company_name
    participants = Participant.where(company_id: nil)
                              .where.not(company_name: [ nil, "" ])
                              .pluck(:id, :name, :company_name)

    Rails.logger.info "[LINK] Found #{participants.length} participants to match"

    linked = 0
    unmatched = 0
    unmatched_names = Hash.new(0)

    participants.each do |id, name, company_name|
      next if company_name.nil? || company_name.strip.empty?

      company_lower = company_name.strip.downcase

      # Try exact match first
      match = exact_match[company_lower]

      # Try prefix match if no exact match
      # (participant company "Deloitte" matches "Deloitte Consulting LLP")
      unless match
        match = company_list.find { |c| c[:name_lower].start_with?(company_lower) }
      end

      # Try reverse prefix (company name starts with participant's company value)
      # (company "IBM" matches participant company "IBM Corporation")
      unless match
        match = company_list.find { |c| company_lower.start_with?(c[:name_lower]) }
      end

      if match
        Participant.where(id: id).update_all(company_id: match[:id])
        linked += 1
      else
        unmatched += 1
        unmatched_names[company_name.strip] += 1
      end

      # Progress log every 500
      if (linked + unmatched) % 500 == 0
        Rails.logger.info "[LINK] Progress: #{linked + unmatched}/#{participants.length} (#{linked} linked, #{unmatched} unmatched)"
      end
    end

    # Log top unmatched
    if unmatched_names.any?
      sorted = unmatched_names.sort_by { |_k, v| -v }.first(10)
      Rails.logger.info "[LINK] Top unmatched: #{sorted.to_h.to_json}"
    end

    elapsed = (Time.current - job_start).round(1)
    Rails.logger.info "[LINK] === LinkParticipantsJob Complete ==="
    Rails.logger.info "[LINK] Linked: #{linked}, Unmatched: #{unmatched}, Total: #{participants.length}"
    Rails.logger.info "[LINK] Completed in #{elapsed}s"

    { linked: linked, unmatched: unmatched, total: participants.length }
  end
end
