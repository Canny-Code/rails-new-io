# == Schema Information
#
# Table name: generated_apps
#
#  id                    :integer          not null, primary key
#  build_log_url         :string
#  configuration_options :json             not null
#  description           :text
#  github_repo_name      :string
#  github_repo_url       :string
#  is_public             :boolean          default(TRUE)
#  last_build_at         :datetime
#  name                  :string           not null
#  rails_version         :string           not null
#  ruby_version          :string           not null
#  selected_gems         :json             not null
#  source_path           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :integer          not null
#
# Indexes
#
#  index_generated_apps_on_github_repo_url   (github_repo_url) UNIQUE
#  index_generated_apps_on_name              (name)
#  index_generated_apps_on_user_id           (user_id)
#  index_generated_apps_on_user_id_and_name  (user_id,name) UNIQUE
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class GeneratedApp < ApplicationRecord
  include HasGenerationLifecycle

  broadcasts_to ->(generated_app) { [ :generated_apps, generated_app.user_id ] }
  # TODO: what is this? Seems like it doesn't do shit
  broadcasts_to ->(generated_app) { [ :notification_badge, generated_app.id ] }

  belongs_to :user

  validates :name, presence: true,
                  uniqueness: { scope: :user_id },
                  format: {
                    with: /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i,
                    message: "only allows letters, numbers, dashes and underscores, must start and end with a letter or number"
                  }
  validates :ruby_version, :rails_version, presence: true
  validates :github_repo_url,
    format: {
      with: %r{\Ahttps://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\z},
      message: "must be a valid GitHub repository URL"
    },
    allow_blank: true
end
