class RenameElementCheckboxesToRailsFlagCheckboxes < ActiveRecord::Migration[7.1]
  def change
    rename_table :element_checkboxes, :element_rails_flag_checkboxes
  end
end
