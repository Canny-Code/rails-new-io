class CreatePages < ActiveRecord::Migration[8.0]
  def change
    create_table :pages do |t|
      t.string :title, null: false, index: true
      t.string :slug, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
