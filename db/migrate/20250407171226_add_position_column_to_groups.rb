class AddPositionColumnToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :position, :integer, default: 0
  end
end
