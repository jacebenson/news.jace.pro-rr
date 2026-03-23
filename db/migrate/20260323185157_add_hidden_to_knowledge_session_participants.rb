class AddHiddenToKnowledgeSessionParticipants < ActiveRecord::Migration[8.0]
  def change
    add_column :knowledge_session_participants, :hidden, :boolean, default: false, null: false
  end
end
