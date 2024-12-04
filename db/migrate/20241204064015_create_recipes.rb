class CreateRecipes < ActiveRecord::Migration[8.0]
  def change
    create_table :recipes do |t|
      t.string :name, null: false
      t.text :description
      t.string :cli_flags
      t.string :ruby_version
      t.string :rails_version
      t.string :status, default: 'draft'
      t.string :head_commit_sha
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
