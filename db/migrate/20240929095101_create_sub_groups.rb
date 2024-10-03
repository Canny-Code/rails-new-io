class CreateSubGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_groups do |t|
      t.string :title, null: false, index: true
      t.references :group, null: false, foreign_key: true, index: true

      t.timestamps
    end
  end
end
