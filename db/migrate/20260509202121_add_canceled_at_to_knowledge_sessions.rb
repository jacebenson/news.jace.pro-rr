class AddCanceledAtToKnowledgeSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :knowledge_sessions, :canceled_at, :datetime
    add_index :knowledge_sessions, :canceled_at
  end
end
