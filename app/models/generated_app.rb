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
#  selected_gems         :json             not null
#  workspace_path        :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  recipe_id             :integer          not null
#  user_id               :integer          not null
#
# Indexes
#
#  index_generated_apps_on_github_repo_url   (github_repo_url) UNIQUE
#  index_generated_apps_on_name              (name)
#  index_generated_apps_on_recipe_id         (recipe_id)
#  index_generated_apps_on_user_id           (user_id)
#  index_generated_apps_on_user_id_and_name  (user_id,name) UNIQUE
#
# Foreign Keys
#
#  recipe_id  (recipe_id => recipes.id)
#  user_id    (user_id => users.id)
#
class GeneratedApp < ApplicationRecord
  include HasGenerationLifecycle
  include GitBackedModel

  delegate :ruby_version, :rails_version, to: :recipe

  belongs_to :user
  belongs_to :recipe

  has_one :app_status, dependent: :destroy
  has_many :app_changes, dependent: :destroy
  has_many :log_entries, class_name: "AppGeneration::LogEntry", dependent: :destroy

  validates :name, presence: true,
                  uniqueness: { scope: :user_id },
                  format: {
                    with: /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i,
                    message: "only allows letters, numbers, dashes and underscores, must start and end with a letter or number"
                  }

  validates :github_repo_url,
    format: {
      with: %r{\Ahttps://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\z},
      message: "must be a valid GitHub repository URL"
    },
    allow_blank: true
  validates :recipe, presence: true

  after_update_commit :broadcast_clone_box, if: :completed?

  broadcasts_to ->(generated_app) { [ :generated_apps, generated_app.user_id ] }
  broadcasts_to ->(generated_app) { [ :notification_badge, generated_app.user_id ] }

  def cleanup_after_push?
    true
  end

  def apply_ingredient!(ingredient, configuration = {})
    logger = AppGeneration::Logger.new(self)

    transaction do
      logger.info("Applying ingredient...", {
        ingredient: ingredient.name,
        workspace_path:,
        pwd: Dir.pwd
      })

      # Create recipe change first
      recipe_change = recipe.recipe_changes.create!(
        ingredient: ingredient,
        change_type: "add_ingredient",
        change_data: { configuration: configuration }
      )

      # Create AppChange linked to the RecipeChange
      app_changes.create!(
        recipe_change: recipe_change,
        configuration: configuration
      )

      template_path = DataRepositoryService.new(user: user).template_path(ingredient)

      require "rails/generators"
      require "rails/generators/rails/app/app_generator"

      app_directory_path = File.join(workspace_path, name)

      Dir.chdir(app_directory_path) do
        ENV["BUNDLE_GEMFILE"] = File.join(Dir.pwd, "Gemfile")

        Rails.application.config.generators.templates += [ File.dirname(template_path) ]

        generator = Rails::Generators::AppGenerator.new(
          [ "." ],
          template: template_path,
          force: true,
          quiet: false,
          pretend: false,
          skip_bundle: true,
          **configuration.symbolize_keys
        )

        generator.apply(template_path)
      end
    end
  rescue StandardError => e
    logger.error("Failed to apply ingredient", {
      error: e.message,
      backtrace: e.backtrace.first(20),
      pwd: Dir.pwd
    })
    raise
  end

  def command
    "rails new #{name} #{recipe.cli_flags}"
  end

  def ingredients
    recipe.recipe_ingredients.includes(:ingredient).map(&:ingredient)
  end

  def on_git_error(error)
    app_status.fail!(error.message)
  end

  private

  def broadcast_clone_box
    Turbo::StreamsChannel.broadcast_update_to(
      "#{to_gid}:app_generation_log_entries",
      target: "github_clone_box",
      partial: "shared/github_clone_box",
      locals: { generated_app: self }
    )
  end
end
