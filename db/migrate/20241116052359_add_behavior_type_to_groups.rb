class AddBehaviorTypeToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :behavior_type, :string
  end
end
