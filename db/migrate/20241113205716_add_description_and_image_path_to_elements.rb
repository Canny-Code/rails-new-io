class AddDescriptionAndImagePathToElements < ActiveRecord::Migration[8.0]
  def change
    add_column :elements, :description, :text
    add_column :elements, :image_path, :string
  end
end
