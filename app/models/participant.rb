class Participant < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :company, optional: true

  has_many :news_item_participants, dependent: :destroy
  has_many :news_items, through: :news_item_participants

  has_many :knowledge_session_participants, dependent: :destroy
  has_many :knowledge_sessions, through: :knowledge_session_participants

  has_many :mvp_awards, dependent: :destroy
  has_many :snapp_cards, dependent: :destroy
  has_many :startup_founders, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def slug
    name.parameterize
  end

  # Find participant by slug (parameterized name)
  # Uses SQL LOWER() to do case-insensitive search without loading all records
  def self.find_by_slug(slug)
    return nil if slug.blank?

    # Try exact name match first
    result = find_by(name: slug)
    return result if result

    # Convert slug back to potential name formats and search
    # e.g., "john-doe" could be "John Doe", "john doe", "JOHN DOE", etc.
    normalized_slug = slug.to_s.downcase.gsub(/[^a-z0-9]/, "")

    # Search using SQL - compare normalized versions
    # This avoids loading all records into memory
    where("LOWER(REPLACE(REPLACE(REPLACE(name, ' ', ''), '-', ''), '_', '')) = ?", normalized_slug).first
  end

  # Normalize a name for comparison (removes common variations)
  def self.normalize_name(name)
    return nil if name.blank?

    name = name.to_s.strip

    # Convert CamelCase to spaced (JaceNow -> Jace Now)
    name = name.gsub(/([a-z])([A-Z])/, '\1 \2')

    # Remove common suffixes/titles
    name = name.gsub(/,\s*(Jr|Sr|II|III|IV|V|PhD|MBA|CEO|CTO|VP|SVP|Director|Manager)\.?$/i, "")

    # Standardize spacing and case
    name = name.squeeze(" ").strip.downcase

    name
  end

  # Find participant by name, checking multiple strategies
  # 1. Exact match on name
  # 2. Match on normalized name
  # 3. Match on aliases (exact or normalized)
  def self.find_by_name_variants(name)
    return nil if name.blank?

    normalized = normalize_name(name)

    # Try exact match
    participant = find_by("LOWER(name) = LOWER(?)", name)
    return participant if participant

    # Try normalized match
    participant = find_by("LOWER(name) = ?", normalized)
    return participant if participant

    # Try aliases - check if name appears in any alias array
    # SQLite JSON: alias is stored as JSON array like '["alias1", "alias2"]'
    participant = where("EXISTS (
      SELECT 1 FROM json_each(alias)
      WHERE LOWER(json_each.value) = LOWER(?)
    )", name).first
    return participant if participant

    # Try normalized alias match
    participant = where("EXISTS (
      SELECT 1 FROM json_each(alias)
      WHERE LOWER(json_each.value) = ?
    )", normalized).first
    return participant if participant

    nil
  end

  # Smart find_or_create that prevents duplicates across name variations
  # Usage: Participant.find_or_create_by_name!("JaceNow") will return "Jace Benson" if aliased
  def self.find_or_create_by_name!(name, &block)
    # First try to find by any name variant
    participant = find_by_name_variants(name)
    return participant if participant

    # Normalize the name for creation
    normalized_name = normalize_name(name)&.titleize || name

    # Create new participant
    create!({ name: normalized_name }, &block)
  rescue ActiveRecord::RecordInvalid => e
    # Handle race condition - someone else created it
    if e.message.include?("Name has already been taken")
      find_by_name_variants(name) || raise
    else
      raise
    end
  end

  # Find potential duplicates based on normalized name similarity
  def self.find_potential_duplicates
    # Group by normalized name and find groups with multiple participants
    all.group_by { |p| normalize_name(p.name) }
       .select { |normalized_name, participants| participants.size > 1 && normalized_name.present? }
       .transform_values { |participants| participants.sort_by(&:name) }
  end

  # Check if this participant might be a duplicate of another
  def potential_duplicates
    return [] if name.blank?

    normalized = self.class.normalize_name(name)
    return [] if normalized.blank?

    # Find other participants with same normalized name
    Participant.where.not(id: id)
               .select { |p| self.class.normalize_name(p.name) == normalized }
  end

  # Scopes for filtering participants with specific data
  scope :with_mvp_awards, -> { joins(:mvp_awards).distinct }
  scope :with_snapp_cards, -> { joins(:snapp_cards).distinct }
  scope :with_startup_founders, -> { joins(:startup_founders).distinct }

  # Helper methods to check if participant has specific data
  def has_mvp_awards?
    mvp_awards.exists?
  end

  def has_snapp_cards?
    snapp_cards.exists?
  end

  def is_startup_founder?
    startup_founders.exists?
  end

  # Get all MVP award years
  def mvp_years
    mvp_awards.pluck(:year).uniq.sort.reverse
  end

  # Get MVP awards grouped by year
  def mvp_awards_by_year
    mvp_awards.recent_first.group_by(&:year)
  end

  # Count of MVP awards
  def mvp_award_count
    mvp_awards.count
  end

  # Get unique award types
  def mvp_award_types
    mvp_awards.pluck(:award_type).uniq
  end

  # Merge another participant into this one
  # source: the participant to merge (will be deleted)
  # field_choices: hash of field names => 'source' or 'target' indicating which value to keep
  def merge!(source, field_choices = {})
    raise ArgumentError, "Cannot merge a participant into itself" if id == source.id

    ActiveRecord::Base.transaction do
      # Store source name before any changes
      source_name = source.name

      # If we're keeping the source's name, nullify it first to avoid uniqueness conflict
      # We use update_column to bypass validations
      if field_choices["name"] == "source" && source_name.present? && source_name != self.name
        source.update_column(:name, nil)
      end

      # Update scalar fields based on choices
      merge_fields = %w[name title bio image_url linkedin_url company_name]
      merge_fields.each do |field|
        if field_choices[field] == "source"
          # For name, use the stored value since we nullified source.name
          value = field == "name" ? source_name : source[field]
          self[field] = value if value.present?
        end
      end

      # Handle company_id separately
      if field_choices["company_id"] == "source" && source.company_id.present?
        self.company_id = source.company_id
      end

      # Handle user_id - keep target's user_id unless target doesn't have one
      if user_id.nil? && source.user_id.present?
        self.user_id = source.user_id
      end

      # Add source name to alias for searchability
      current_aliases = if self[:alias].present?
        begin
          JSON.parse(self[:alias])
        rescue JSON::ParserError
          []
        end
      else
        []
      end
      current_aliases << source_name unless current_aliases.include?(source_name)
      write_attribute(:alias, current_aliases.to_json)

      save!

      # Transfer news items
      source.news_item_participants.find_each do |nip|
        begin
          nip.update!(participant: self)
        rescue ActiveRecord::RecordNotUnique
          # Duplicate association, destroy the source's
          nip.destroy!
        end
      end

      # Transfer knowledge sessions
      source.knowledge_session_participants.find_each do |ksp|
        begin
          ksp.update!(participant: self)
        rescue ActiveRecord::RecordNotUnique
          ksp.destroy!
        end
      end

      # Transfer MVP awards (skip duplicates based on year + award_type)
      source.mvp_awards.find_each do |award|
        unless mvp_awards.exists?(year: award.year, award_type: award.award_type)
          award.update!(participant: self)
        end
      end

      # Transfer Snapp cards (skip duplicates based on edition + card_name)
      source.snapp_cards.find_each do |card|
        unless snapp_cards.exists?(edition: card.edition, card_name: card.card_name)
          card.update!(participant: self)
        end
      end

      # Transfer startup founders (skip duplicates based on company_name)
      source.startup_founders.find_each do |founder|
        unless startup_founders.exists?(company_name: founder.company_name)
          founder.update!(participant: self)
        end
      end

      # Destroy the source participant
      source.destroy!
    end

    self
  end

  # Get all related record counts for display
  def related_counts
    {
      news_items: news_items.count,
      knowledge_sessions: knowledge_sessions.count,
      mvp_awards: mvp_awards.count,
      snapp_cards: snapp_cards.count,
      startup_founders: startup_founders.count
    }
  end
end
