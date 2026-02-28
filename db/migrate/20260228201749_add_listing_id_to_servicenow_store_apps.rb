class AddListingIdToServicenowStoreApps < ActiveRecord::Migration[8.0]
  def change
    add_column :servicenow_store_apps, :listing_id, :string
  end
end
