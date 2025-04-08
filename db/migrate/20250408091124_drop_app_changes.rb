class DropAppChanges < ActiveRecord::Migration[8.0]
  def change
    drop_table :app_changes
  end
end
