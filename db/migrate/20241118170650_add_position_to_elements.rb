class AddPositionToElements < ActiveRecord::Migration[8.0]
  def change
    add_column :elements, :position, :integer, null: true
    add_index :elements, :position
  end
end
