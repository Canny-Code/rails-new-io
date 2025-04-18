class AddOnboardingCompletedColumnToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :onboarding_completed, :boolean, default: false
  end
end
