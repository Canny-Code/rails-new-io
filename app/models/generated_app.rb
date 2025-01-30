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

  attr_writer :logger

  delegate :ruby_version, :rails_version, to: :recipe

  belongs_to :user
  belongs_to :recipe

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

  def cleanup_after_push?
    true
  end

  def apply_ingredients
    repository_service = AppRepositoryService.new(self, @logger)

    unless ingredients.any?
      @logger.info("No ingredients to apply - moving on")
      return
    end

    ingredients.each do |ingredient|
      apply_ingredient(ingredient)

      @logger.info("Committing ingredient changes")
      repository_service.commit_changes_after_applying_ingredient(ingredient)
      @logger.info("Ingredient applied successfully", { name: ingredient.name })
    end
  end

  def start_ci
    # future hook for custom CI - right now, it's just a status update
    # CI run is handled by GitHub Actions
    app_status.start_ci!
  end

  def complete
    # hook to do stuff after app generation is complete
    app_status.complete!
  end

  def command
    "rails new #{name} #{recipe.cli_flags}"
  end

  def ingredients
    @_ingredients ||= recipe.recipe_ingredients.includes(:ingredient).map(&:ingredient)
  end

  def on_git_error(error)
    app_status.fail!(error.message)
  end

  private

  def apply_ingredient(ingredient, configuration = {})
    @logger.info("Applying ingredient", { name: ingredient.name })

    transaction do
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

      template_path = DataRepositoryService.new(user:).template_path(ingredient)

      unless File.exist?(template_path)
        @logger.error("Template file not found", { path: template_path })
        raise "Template file not found: #{template_path}"
      end


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
    @logger.error("Failed to apply ingredient", {
      error: e.message,
      backtrace: e.backtrace.first(20),
      pwd: Dir.pwd
    })
    raise
  end

  def broadcast_clone_box
    Turbo::StreamsChannel.broadcast_update_to(
      "#{to_gid}:app_generation_log_entries",
      target: "github_clone_box",
      partial: "shared/github_clone_box",
      locals: { generated_app: self }
    )
  end
end
