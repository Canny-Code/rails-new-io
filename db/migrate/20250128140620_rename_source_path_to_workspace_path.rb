class RenameSourcePathToWorkspacePath < ActiveRecord::Migration[8.0]
  def change
    rename_column :generated_apps, :source_path, :workspace_path
  end
end
