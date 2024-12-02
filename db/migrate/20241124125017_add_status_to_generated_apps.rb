class AddStatusToGeneratedApps < ActiveRecord::Migration[7.0]
  def change
    add_column :generated_apps, :status, :string, default: "pending"
    add_index :generated_apps, :status
  end
end
