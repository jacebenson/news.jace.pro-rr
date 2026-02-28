class StartupFounder < ApplicationRecord
  belongs_to :participant

  validates :company_name, presence: true
  validates :participant_id, uniqueness: { scope: :company_name, message: "is already a founder of this company" }

  scope :by_company, ->(company) { where(company_name: company) }
  scope :with_source, -> { where.not(source_url: [ nil, "" ]) }

  def display_name
    "#{participant.name} - #{company_name}"
  end
end
