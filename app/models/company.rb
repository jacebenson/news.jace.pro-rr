class Company < ApplicationRecord
  has_many :participants, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :partners, -> { where(is_partner: true) }
  scope :customers, -> { where(is_customer: true) }

  # JSON array fields
  def alias_list
    JSON.parse(self.alias || "[]")
  rescue JSON::ParserError
    []
  end

  def products_list
    JSON.parse(products || "[]")
  rescue JSON::ParserError
    []
  end

  def services_list
    JSON.parse(services || "[]")
  rescue JSON::ParserError
    []
  end
end
