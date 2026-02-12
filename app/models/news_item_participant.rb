class NewsItemParticipant < ApplicationRecord
  belongs_to :news_item
  belongs_to :participant
end
