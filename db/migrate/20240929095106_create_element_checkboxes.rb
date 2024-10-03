class CreateElementCheckboxes < ActiveRecord::Migration[8.0]
  def change
    create_table :element_checkboxes do |t|
      t.boolean :default
      t.boolean :checked

      t.timestamps
    end
  end
end
