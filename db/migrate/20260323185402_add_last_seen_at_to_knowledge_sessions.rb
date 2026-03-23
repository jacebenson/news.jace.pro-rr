class AddLastSeenAtToKnowledgeSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :knowledge_sessions, :last_seen_at, :datetime
  end
end
