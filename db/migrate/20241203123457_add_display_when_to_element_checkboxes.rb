class AddDisplayWhenToElementCheckboxes < ActiveRecord::Migration[8.0]
  def change
    add_column :element_checkboxes, :display_when, :string, default: 'checked'
  end
end
