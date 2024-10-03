class CreateElementTextFields < ActiveRecord::Migration[8.0]
  def change
    create_table :element_text_fields do |t|
      t.string :default_value
      t.string :value
      t.integer :max_length

      t.timestamps
    end
  end
end
