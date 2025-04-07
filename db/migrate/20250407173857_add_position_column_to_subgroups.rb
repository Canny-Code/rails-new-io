class AddPositionColumnToSubgroups < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_groups, :position, :integer, default: 0
  end
end
