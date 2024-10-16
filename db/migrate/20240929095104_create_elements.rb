class CreateElements < ActiveRecord::Migration[8.0]
  def change
    create_table :elements do |t|
      t.string :label, null: false, index: true
      t.references :sub_group, foreign_key: true
      t.string :variant_type
      t.string :variant_id


      t.timestamps
    end

    add_index :elements, [ :variant_type, :variant_id ]
  end
end
