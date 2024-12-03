class AddCommandLineValueToElements < ActiveRecord::Migration[8.0]
  def change
    add_column :elements, :command_line_value, :string
    add_index :elements, :command_line_value
  end
end
