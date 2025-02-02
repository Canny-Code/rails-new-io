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
require "test_helper"

class GeneratedAppTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @recipe = recipes(:blog_recipe)
    @generated_app = generated_apps(:pending_app)

    # Create test directories matching the fixture
    @workspace_path = create_test_directory("test_apps/pending_app")
    @app_directory = File.join(@workspace_path, @generated_app.name)

    FileUtils.mkdir_p(@app_directory)
    FileUtils.touch(File.join(@app_directory, "Gemfile"))

    @generated_app.update!(workspace_path: @workspace_path)

    @logger = mock("logger")
    @logger.stubs(:info)
    @logger.stubs(:error)
    @generated_app.logger = @logger
  end

  test "creates app status after creation" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    assert_not_nil app.app_status
    assert app.app_status.pending?
  end

  test "validates presence of required fields" do
    app = GeneratedApp.new
    assert_not app.valid?
    assert_includes app.errors[:name], "can't be blank"
    assert_includes app.errors[:user], "must exist"
  end

  test "validates name format" do
    invalid_names = [
      "my app",        # Contains space
      "my/app",        # Contains slash
      "-my-app",       # Starts with dash
      "my-app-",       # Ends with dash
      "MY APP!",       # Contains special character
      "app@123"        # Contains special character
    ]

    invalid_names.each do |invalid_name|
      app = GeneratedApp.new(
        name: invalid_name,
        user: @user,
        recipe: @recipe,
        selected_gems: [],
        configuration_options: {}
      )
      assert_not app.valid?, "#{invalid_name} should be invalid"
      assert_includes app.errors[:name], "only allows letters, numbers, dashes and underscores, must start and end with a letter or number"
    end

    valid_names = [
      "my-app",
      "myapp",
      "my_app",
      "app123",
      "123app",
      "my-awesome-app-123"
    ]

    valid_names.each do |valid_name|
      app = GeneratedApp.new(
        name: valid_name,
        user: @user,
        recipe: @recipe,
        selected_gems: [],
        configuration_options: {}
      )
      assert app.valid?, "#{valid_name} should be valid"
    end
  end

  test "validates uniqueness of name scoped to user" do
    GeneratedApp.create!(
      name: "my-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    second_app = GeneratedApp.new(
      name: "my-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    assert_not second_app.valid?
    assert_includes second_app.errors[:name], "has already been taken"
  end

  test "delegates status methods to app_status" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    assert_respond_to app, :status
    assert_respond_to app, :started_at
    assert_respond_to app, :completed_at
    assert_respond_to app, :error_message
  end

  test "handles json fields" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [ "devise", "rspec" ],
      configuration_options: { database: "postgresql", css: "tailwind" }
    )

    app.reload
    assert_equal [ "devise", "rspec" ], app.selected_gems
    assert_equal({ "database" => "postgresql", "css" => "tailwind" }, app.configuration_options)
  end

  test "destroys associated app_status when destroyed" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    status_id = app.app_status.id
    app.destroy

    assert_nil AppStatus.find_by(id: status_id)
  end

  test "lifecycle methods" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    # Initial state
    assert app.app_status.pending?
    assert_nil app.started_at
    assert_nil app.completed_at
    assert_nil app.error_message

    # Create GitHub repo
    app.start_github_repo_creation!
    assert app.app_status.creating_github_repo?

    # Start generation
    assert_changes -> { app.reload.last_build_at } do
      app.start_rails_app_generation!
    end
    assert app.generating_rails_app?

    # Apply ingredients
    assert_changes -> { app.reload.last_build_at } do
      app.start_ingredient_application!
    end
    assert app.applying_ingredients?

    # Push to GitHub
    assert_changes -> { app.reload.last_build_at } do
      app.start_github_push!
    end
    assert app.app_status.pushing_to_github?

    # Start CI
    assert_changes -> { app.reload.last_build_at } do
      app.start_ci!
    end
    assert app.running_ci?

    # Complete generation
    assert_changes -> { app.reload.last_build_at } do
      app.complete!
    end
    assert app.completed?

    # Fail generation (from pending)
    app = GeneratedApp.create!(
      name: "test-app-2",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )
    error_message = "Something went wrong"
    app.fail!(error_message)
    assert app.app_status.failed?

    assert_equal error_message, app.reload.app_status.reload.error_message

    # Reset status
    app.restart!
    assert app.app_status.pending?
    assert_nil app.error_message
  end

  test "broadcasts clone box when completed" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {},
      github_repo_url: "https://github.com/johndoe/test-app"
    )

    # Follow the proper state transition sequence
    app.start_github_repo_creation!
    app.start_rails_app_generation!
    app.start_ingredient_application!
    app.start_github_push!
    app.start_ci!

    assert_broadcasts_to("#{app.to_gid}:app_generation_log_entries") do
      app.complete!
    end
  end

  test "follows complete lifecycle with github repo creation" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    # Initial state
    assert app.app_status.pending?
    assert_nil app.started_at
    assert_nil app.completed_at
    assert_nil app.error_message

    # Create GitHub repo
    assert_changes -> { app.reload.last_build_at } do
      app.start_github_repo_creation!
    end
    assert app.app_status.creating_github_repo?

    # Start generation
    assert_changes -> { app.reload.last_build_at } do
      app.start_rails_app_generation!
    end
    assert app.generating_rails_app?

    # Apply ingredients
    assert_changes -> { app.reload.last_build_at } do
      app.start_ingredient_application!
    end
    assert app.applying_ingredients?

    # Push to GitHub
    assert_changes -> { app.reload.last_build_at } do
      app.start_github_push!
    end
    assert app.app_status.pushing_to_github?

    # Start CI
    assert_changes -> { app.reload.last_build_at } do
      app.start_ci!
    end
    assert app.running_ci?

    # Complete generation
    assert_changes -> { app.reload.last_build_at } do
      app.complete!
    end
    assert app.completed?
  end

  test "on_git_error fails app status with error message" do
    app = generated_apps(:pending_app)
    error = StandardError.new("Git repository error occurred")

    app.on_git_error(error)

    assert app.app_status.failed?
    assert_equal "Git repository error occurred", app.app_status.error_message
  end

  test "apply_ingredients does nothing when there are no ingredients" do
    app = generated_apps(:no_ingredients_app)

    logger = mock("logger")
    logger.expects(:info).with("No ingredients to apply - moving on")
    app.logger = logger

    app.apply_ingredients
  end

  test "apply_ingredients applies all ingredients in order" do
    @generated_app.update!(recipe: @recipe)

    git_service = mock("git_service")
    repository_service = AppRepositoryService.new(@generated_app, @logger)
    repository_service.stubs(:git_service).returns(git_service)
    @generated_app.repository_service = repository_service

    # Create the template file
    template_path = DataRepositoryService.new(user: @user).template_path(@recipe.ingredients.first)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, @recipe.ingredients.first.template_content)

    @recipe.ingredients.each do |ingredient|
      @logger.expects(:info).with("Applying ingredient", { name: ingredient.name })
      @logger.expects(:info).with("Ingredient applied successfully", { name: ingredient.name })
      @logger.expects(:info).with("Committing ingredient changes")
      git_service.expects(:commit_changes).with(message: ingredient.to_commit_message)
    end

    @generated_app.apply_ingredients
  end

  test "to_commit_message for an app without ingredients doesn't contain message about ingredients" do
    app = generated_apps(:no_ingredients_app)
    assert_equal "Initial commit by railsnew.io\n\ncommand line flags:\n\n--minimal\n\n\n", app.to_commit_message
  end

  test "raises error when template path doesn't exist" do
    repository_service = mock("repository_service")
    @generated_app.stubs(:repository_service).returns(repository_service)

    DataRepositoryService.any_instance
      .expects(:template_path)
      .returns("/nonexistent/path/template.rb")

    @logger.expects(:error).with(
      "Template file not found",
      { path: "/nonexistent/path/template.rb" }
    )

    error = assert_raises(RuntimeError) do
      @generated_app.apply_ingredients
    end

    assert_equal "Template file not found: /nonexistent/path/template.rb", error.message
  end
end
