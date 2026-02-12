class KnowledgeSessionParticipant < ApplicationRecord
  belongs_to :knowledge_session
  belongs_to :participant
end
