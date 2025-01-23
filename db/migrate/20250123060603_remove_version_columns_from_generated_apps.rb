class RemoveVersionColumnsFromGeneratedApps < ActiveRecord::Migration[8.0]
  def change
    remove_column :generated_apps, :ruby_version, :string
    remove_column :generated_apps, :rails_version, :string
  end
end
