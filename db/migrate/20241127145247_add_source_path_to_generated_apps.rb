class AddSourcePathToGeneratedApps < ActiveRecord::Migration[8.0]
  def change
    add_column :generated_apps, :source_path, :string
  end
end
