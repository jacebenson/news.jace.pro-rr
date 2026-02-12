class ServicenowStoreApp < ApplicationRecord
  validates :source_app_id, presence: true, uniqueness: true

  scope :search, ->(term) { where("title LIKE ? OR company_name LIKE ? OR tagline LIKE ?", "%#{term}%", "%#{term}%", "%#{term}%") }
  scope :by_company, ->(company) { where("company_name LIKE ?", "%#{company}%") }
  scope :recent, -> { order(published_at: :desc) }
  scope :popular, -> { order(purchase_count: :desc) }
end
