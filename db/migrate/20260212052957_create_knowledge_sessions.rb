class CreateKnowledgeSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_sessions do |t|
      t.string :code
      t.string :session_id
      t.string :title
      t.string :title_sort
      t.text :abstract
      t.string :published
      t.datetime :modified
      t.string :event_id
      t.text :participants
      t.text :times
      t.string :recording_url

      t.timestamps
    end
    add_index :knowledge_sessions, :session_id, unique: true
  end
end
