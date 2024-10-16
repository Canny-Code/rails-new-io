class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :title, null: false, index: true
      t.references :page, null: false, foreign_key: true, index: true

      t.timestamps
    end
  end
end
