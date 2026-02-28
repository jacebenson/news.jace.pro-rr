class SnappCard < ApplicationRecord
  belongs_to :participant

  validates :edition, presence: true
  validates :card_name, presence: true
  validates :participant_id, uniqueness: { scope: [ :edition, :card_name ], message: "already has this card for this edition" }

  scope :by_edition, ->(edition) { where(edition: edition) }
  scope :recent_first, -> { order(edition: :desc, created_at: :desc) }

  def display_name
    "#{card_name} (#{edition})"
  end
end
