class AddGithubUsernameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :github_username, :string

    User.find_each do |user|
      # temporary, against the null constraint
      # it'll be updated when the user logs in
      user.update_column(:github_username, user.uid)
    end

    change_column_null :users, :github_username, false
    add_index :users, :github_username, unique: true
  end
end
