class CreateKnowledgeSessionParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_session_participants do |t|
      t.references :knowledge_session, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true

      t.timestamps
    end
  end
end
