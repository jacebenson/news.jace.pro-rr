class ServicenowInvestment < ApplicationRecord
  # Handle date column that may contain milliseconds (legacy) or Time objects
  def date
    raw = super
    return nil if raw.nil?
    return raw if raw.is_a?(Time) || raw.is_a?(Date)
    Time.at(raw / 1000) if raw.is_a?(Integer)
  end
end
