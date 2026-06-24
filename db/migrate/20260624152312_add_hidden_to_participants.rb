class AddHiddenToParticipants < ActiveRecord::Migration[8.0]
  def change
    add_column :participants, :hidden, :boolean
  end
end
