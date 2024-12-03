class AddDescriptionToGroups < ActiveRecord::Migration[7.1]
  def change
    add_column :groups, :description, :string, null: true
  end
end
