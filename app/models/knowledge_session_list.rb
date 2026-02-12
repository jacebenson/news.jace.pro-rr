class KnowledgeSessionList < ApplicationRecord
  belongs_to :knowledge_session
  belongs_to :user
end
