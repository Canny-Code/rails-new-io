# == Schema Information
#
# Table name: generated_apps
#
#  id                            :integer          not null, primary key
#  build_log_url                 :string
#  configuration_options         :json             not null
#  description                   :text
#  generated_with_recipe_version :string           default("unknown"), not null
#  github_repo_name              :string
#  github_repo_url               :string
#  is_public                     :boolean          default(TRUE)
#  last_build_at                 :datetime
#  name                          :string           not null
#  selected_gems                 :json             not null
#  workspace_path                :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  recipe_id                     :integer          not null
#  user_id                       :integer          not null
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
  validates :generated_with_recipe_version, presence: true

  def apply_ingredients
    unless ingredients.any?
      @logger.info("No ingredients to apply - moving on")
      return
    end

    ingredients.each do |ingredient|
      apply_ingredient(ingredient)

      @logger.info("Committing ingredient changes")
      @repository_service.commit_changes(<<~COMMIT_MESSAGE)
      Applied ingredient:

      #{ingredient.to_commit_message}
      COMMIT_MESSAGE
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

    cli_flags_list_or_omakase = if recipe.cli_flags.squish.strip.blank?
      "None (Omakase)"
    else
      recipe.cli_flags.squish.strip
    end

    <<~INITIAL_COMMIT_MESSAGE
    Initial commit by railsnew.io

    ===================
    Command line flags:
    ===================

    #{cli_flags_list_or_omakase}

    #{ingredients_message}
    INITIAL_COMMIT_MESSAGE
  end

  def add_schema_rb
    schema_path = File.join(workspace_path, name, "db/schema.rb")
    FileUtils.mkdir_p(File.dirname(schema_path))
    File.write(schema_path, <<~SCHEMA)
      # This file is auto-generated from the current state of the database. Instead
      # of editing this file, please use the migrations feature of Active Record to
      # incrementally modify your database, and then regenerate this schema definition.
      #
      # This file is the source Rails uses to define your schema when running `bin/rails
      # db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
      # be faster and is potentially less error prone than running all of your
      # migrations from scratch. Old migrations may fail to apply correctly if those
      # migrations use external dependencies or application code.
      #
      # It's strongly recommended that you check this file into your version control system.

      ActiveRecord::Schema[8.0].define(version: 0) do
      end
    SCHEMA
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

    template_path = DataRepositoryService.new(user:).template_path(ingredient)

    unless File.exist?(template_path)
      @logger.error("Template file not found", { path: template_path })
      raise "Template file not found: #{template_path}"
    end

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

    Turbo::StreamsChannel.broadcast_update_to(
      "#{to_gid}:app_generation_log_entries",
      target: "explanation",
      partial: "shared/onboarding/7/final_instructions"
    )

    # TODO: This is a hack to broadcast the last step as completed
    app_status.broadcast_status_steps
  end
end
