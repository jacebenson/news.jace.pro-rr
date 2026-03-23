class AddUrlToKnowledgeSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :knowledge_sessions, :url, :string
  end
end
