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

  attr_writer :logger, :repository_service

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

  def apply_ingredients
    unless ingredients.any?
      @logger.info("No ingredients to apply - moving on")
      return
    end

    ingredients.each do |ingredient|
      apply_ingredient(ingredient)

      @logger.info("Committing ingredient changes")
      @repository_service.commit_changes(ingredient.to_commit_message)
      @logger.info("Ingredient #{ingredient.name} applied successfully")
    end
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

  def to_commit_message
    ingredients_message = if recipe.ingredients.any?
      <<~INGREDIENTS_MESSAGE
      ============
      Ingredients:
      ============

      #{recipe.ingredients.map(&:to_commit_message).join("\n\n")}
      INGREDIENTS_MESSAGE
    else
      ""
    end

    <<~INITIAL_COMMIT_MESSAGE
    Initial commit by railsnew.io

    command line flags:

    #{recipe.cli_flags.squish.strip}

    #{ingredients_message}
    INITIAL_COMMIT_MESSAGE
  end

  def configured_databases(env = "development")
    database_yml_path = File.join(workspace_path, name, "config", "database.yml")
    puts "database_yml_path: #{database_yml_path}"
    return [] unless File.exist?(database_yml_path)

    database_yaml = YAML.load_file(database_yml_path, aliases: true)

    stuff = database_yaml.each_with_object([]) do |(key, value), result|
      if value.is_a?(Hash)
        if value.key?("adapter")
          result << key
        else
          # For nested configs like production: { primary: { adapter: ... } }
          value.each do |subkey, subvalue|
            if subvalue.is_a?(Hash) && subvalue.key?("adapter")
              result << "#{key}/#{subkey}"
            end
          end
        end
      end
    end.select { it.include?("/") }.map { it.split("/").last }.uniq
  end

  private

  def apply_ingredient(ingredient, configuration = {})
    @logger.info("Applying ingredient: #{ingredient.name}")

    app_directory_path = File.join(workspace_path, name)
    ENV["BUNDLE_GEMFILE"] = File.join(app_directory_path, "Gemfile")

    # Verify Bundler environment
    unless File.exist?(ENV["BUNDLE_GEMFILE"])
      @logger.error("Bundler environment not properly set", {
        bundle_gemfile: ENV["BUNDLE_GEMFILE"],
        gemfile_exists: File.exist?(ENV["BUNDLE_GEMFILE"])
      })
      raise "Bundler environment not properly set"
    end

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

    command = "rails app:template LOCATION=#{template_path}"
    CommandExecutionService.new(self, @logger, command).execute

    # Ensure Gemfile changes are flushed to disk
    if File.exist?("Gemfile")
      File.open("Gemfile", "r+") do |f|
        f.flush
        f.fsync
      end
    end
  rescue StandardError => e
    original_metadata = e.respond_to?(:metadata) ? e.metadata : {}

    @logger.error("Failed to apply ingredient", {
      error: e.message,
      backtrace: e.backtrace.join("<br>"),
      **original_metadata
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
    # TODO: This is a hack to broadcast the last step as completed
    app_status.broadcast_status_steps
  end
end
