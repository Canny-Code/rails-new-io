class AddPositionToPages < ActiveRecord::Migration[8.0]
  def change
    add_column :pages, :position, :integer, null: false, default: 0
    add_index :pages, :position
  end
end
