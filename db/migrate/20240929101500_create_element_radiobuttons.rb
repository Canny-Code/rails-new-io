class CreateElementRadiobuttons < ActiveRecord::Migration[8.0]
  def change
    create_table :element_radio_buttons do |t|
      t.boolean :default
      t.string  :selected_option

      t.timestamps
    end
  end
end
