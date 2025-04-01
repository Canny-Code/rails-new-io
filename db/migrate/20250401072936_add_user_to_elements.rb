class AddUserToElements < ActiveRecord::Migration[8.0]
  def change
    add_reference :elements, :user, null: true, foreign_key: true

    # Set a default user for existing records (using the first admin user)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE elements
          SET user_id = (SELECT id FROM users WHERE github_username = 'rails-new-io' LIMIT 1)
          WHERE user_id IS NULL
        SQL
      end
    end

    change_column_null :elements, :user_id, false
  end
end
