class CreateCommits < ActiveRecord::Migration[8.0]
  def change
    create_table :commits do |t|
      t.string :sha, null: false
      t.text :message, null: false
      t.json :state_snapshot, null: false
      t.string :parent_sha
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :versioned, polymorphic: true, null: false

      t.timestamps

      t.index :sha, unique: true
    end
  end
end
