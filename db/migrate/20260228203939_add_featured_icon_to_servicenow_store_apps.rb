class AddFeaturedIconToServicenowStoreApps < ActiveRecord::Migration[8.0]
  def change
    add_column :servicenow_store_apps, :featured_icon, :string
  end
end
