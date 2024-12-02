class CreateRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      t.string :name, null: false
      t.string :github_url, null: false
      t.references :user, null: false, foreign_key: true, index: true

      t.timestamps

      t.index :name
      t.index :github_url, unique: true
    end
  end
end
