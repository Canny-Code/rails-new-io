class CreateElementUnclassifieds < ActiveRecord::Migration[8.0]
  def change
    create_table :element_unclassifieds do |t|
      t.timestamps
    end
  end
end
