class RemoveStatusFromGeneratedApps < ActiveRecord::Migration[7.0]
  def change
    remove_column :generated_apps, :status, :string
    remove_index :generated_apps, :status if index_exists?(:generated_apps, :status)
  end
end
