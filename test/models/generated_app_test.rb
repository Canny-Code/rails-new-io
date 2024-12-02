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
require "test_helper"

class GeneratedAppTest < ActiveSupport::TestCase
  def setup
    @user = users(:jane)
  end

  test "creates app status after creation" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    assert_not_nil app.app_status
    assert app.app_status.pending?
  end

  test "validates presence of required fields" do
    app = GeneratedApp.new
    assert_not app.valid?
    assert_includes app.errors[:name], "can't be blank"
    assert_includes app.errors[:ruby_version], "can't be blank"
    assert_includes app.errors[:rails_version], "can't be blank"
    assert_includes app.errors[:user], "must exist"
  end

  test "validates name format" do
    invalid_names = [
      "invalid app name",  # spaces not allowed
      "-invalid-start",    # can't start with dash
      "invalid-end-",      # can't end with dash
      "app!name",         # special characters not allowed
      "_invalid_start",    # can't start with underscore
      "invalid_end_"      # can't end with underscore
    ]

    invalid_names.each do |invalid_name|
      app = GeneratedApp.new(
        name: invalid_name,
        user: @user,
        ruby_version: "3.2.0",
        rails_version: "7.1.0"
      )
      assert_not app.valid?, "#{invalid_name} should be invalid"
      assert_includes app.errors[:name], "only allows letters, numbers, dashes and underscores, must start and end with a letter or number"
    end

    valid_names = [
      "my-app",
      "app1",
      "cool-app-123",
      "my_cool_app",
      "App-Name-2"
    ]

    valid_names.each do |valid_name|
      app = GeneratedApp.new(
        name: valid_name,
        user: @user,
        ruby_version: "3.2.0",
        rails_version: "7.1.0"
      )
      assert app.valid?, "#{valid_name} should be valid"
    end
  end

  test "validates uniqueness of name scoped to user" do
    GeneratedApp.create!(
      name: "my-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    second_app = GeneratedApp.new(
      name: "my-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    assert_not second_app.valid?
    assert_includes second_app.errors[:name], "has already been taken"
  end

  test "delegates status methods to app_status" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
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
      ruby_version: "3.2.0",
      rails_version: "7.1.0",
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
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    status_id = app.app_status.id
    app.destroy

    assert_nil AppStatus.find_by(id: status_id)
  end

  test "lifecycle methods" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    # Initial state
    assert app.app_status.pending?
    assert_nil app.started_at
    assert_nil app.completed_at
    assert_nil app.error_message

    # Create GitHub repo
    app.create_github_repo!
    assert app.app_status.creating_github_repo?

    # Start generation
    app.generate!
    assert app.app_status.generating?
    assert_not_nil app.started_at
    assert_nil app.completed_at

    # Push to GitHub
    app.push_to_github!
    assert app.app_status.pushing_to_github?

    # Start CI
    app.start_ci!
    assert app.app_status.running_ci?

    # Complete generation
    app.mark_as_completed!
    assert app.app_status.completed?
    assert_not_nil app.completed_at
    assert_nil app.error_message

    # Fail generation (from pending)
    app = GeneratedApp.create!(
      name: "test-app-2",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )
    error_message = "Something went wrong"
    app.mark_as_failed!(error_message)
    assert app.app_status.failed?

    assert_equal error_message, app.reload.app_status.reload.error_message

    # Reset status
    app.restart!
    assert app.app_status.pending?
    assert_nil app.error_message
  end

  test "notifies status changes" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    assert_difference "Noticed::Event.count" do
      app.create_github_repo!
    end

    assert_difference "Noticed::Event.count" do
      app.generate!
    end

    assert_difference "Noticed::Event.count" do
      app.push_to_github!
    end

    assert_difference "Noticed::Event.count" do
      app.start_ci!
    end

    assert_difference "Noticed::Event.count" do
      app.mark_as_completed!
    end

    # Test failure path with a new app
    app = GeneratedApp.create!(
      name: "test-app-2",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    assert_difference "Noticed::Event.count" do
      app.mark_as_failed!("Error")
    end
  end

  test "updates last_build_at on status changes" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    # Initial state
    assert app.app_status.pending?
    assert_nil app.started_at
    assert_nil app.completed_at
    assert_nil app.error_message

    # Create GitHub repo
    assert_changes -> { app.reload.last_build_at } do
      app.create_github_repo!
    end
    assert app.app_status.creating_github_repo?

    # Start generation
    assert_changes -> { app.reload.last_build_at } do
      app.generate!
    end
    assert app.generating?

    # Push to GitHub
    assert_changes -> { app.reload.last_build_at } do
      app.push_to_github!
    end
    assert app.app_status.pushing_to_github?

    # Start CI
    assert_changes -> { app.reload.last_build_at } do
      app.start_ci!
    end
    assert app.running_ci?

    # Complete generation
    assert_changes -> { app.reload.last_build_at } do
      app.mark_as_completed!
    end
    assert app.completed?

    # Test failure path with a new app
    app = GeneratedApp.create!(
      name: "test-app-2",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )
    error_message = "Something went wrong"
    app.mark_as_failed!(error_message)
    assert app.app_status.failed?

    assert_equal error_message, app.reload.app_status.reload.error_message

    # Reset status
    app.restart!
    assert app.app_status.pending?
    assert_nil app.error_message
  end

  test "follows complete lifecycle with github repo creation" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    # Initial state
    assert app.app_status.pending?
    assert_nil app.started_at
    assert_nil app.completed_at
    assert_nil app.error_message

    # Create GitHub repo
    assert_changes -> { app.reload.last_build_at } do
      app.create_github_repo!
    end
    assert app.app_status.creating_github_repo?

    # Start generation
    assert_changes -> { app.reload.last_build_at } do
      app.generate!
    end
    assert app.generating?

    # Push to GitHub
    assert_changes -> { app.reload.last_build_at } do
      app.push_to_github!
    end
    assert app.app_status.pushing_to_github?

    # Start CI
    assert_changes -> { app.reload.last_build_at } do
      app.start_ci!
    end
    assert app.running_ci?

    # Complete generation
    assert_changes -> { app.reload.last_build_at } do
      app.mark_as_completed!
    end
    assert app.completed?
  end

  test "broadcasts clone box when completed" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0",
      github_repo_url: "https://github.com/johndoe/test-app"
    )

    Turbo::StreamsChannel.expects(:broadcast_update_to).with(
      "#{app.to_gid}:app_generation_log_entries",
      target: "github_clone_box",
      partial: "shared/github_clone_box",
      locals: { generated_app: app }
    )

    app.app_status.update!(status: :pushing_to_github)
    app.app_status.start_ci!
    app.app_status.complete!
  end

  test "lifecycle methods follow correct state transitions" do
    app = GeneratedApp.create!(
      name: "test-app",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )

    # Initial state
    assert app.app_status.pending?
    assert_nil app.started_at
    assert_nil app.completed_at
    assert_nil app.error_message

    # Verify we can't skip states
    assert_raises(AASM::InvalidTransition) { app.generate! }
    assert_raises(AASM::InvalidTransition) { app.push_to_github! }
    assert_raises(AASM::InvalidTransition) { app.start_ci! }
    assert_raises(AASM::InvalidTransition) { app.mark_as_completed! }

    # Create GitHub repo
    app.create_github_repo!
    assert app.app_status.creating_github_repo?

    # Verify we can't skip states after creating repo
    assert_raises(AASM::InvalidTransition) { app.push_to_github! }
    assert_raises(AASM::InvalidTransition) { app.start_ci! }
    assert_raises(AASM::InvalidTransition) { app.mark_as_completed! }

    # Start generation
    app.generate!
    assert app.app_status.generating?
    assert_not_nil app.started_at

    # Verify we can't skip states during generation
    assert_raises(AASM::InvalidTransition) { app.start_ci! }
    assert_raises(AASM::InvalidTransition) { app.mark_as_completed! }

    # Push to GitHub
    app.push_to_github!
    assert app.app_status.pushing_to_github?

    # Verify we can't skip CI
    assert_raises(AASM::InvalidTransition) { app.mark_as_completed! }

    # Start CI
    app.start_ci!
    assert app.app_status.running_ci?

    # Complete generation
    app.mark_as_completed!
    assert app.app_status.completed?
    assert_not_nil app.completed_at
    assert_nil app.error_message
  end

  test "can fail from any non-completed state" do
    error_message = "Something went wrong"

    [ :pending, :creating_github_repo, :generating, :pushing_to_github, :running_ci ].each do |state|
      app = GeneratedApp.create!(
        name: "test-app-#{state}",
        user: @user,
        ruby_version: "3.2.0",
        rails_version: "7.1.0"
      )

      # Move to the target state
      case state
      when :creating_github_repo
        app.create_github_repo!
      when :generating
        app.create_github_repo!
        app.generate!
      when :pushing_to_github
        app.create_github_repo!
        app.generate!
        app.push_to_github!
      when :running_ci
        app.create_github_repo!
        app.generate!
        app.push_to_github!
        app.start_ci!
      end

      app.mark_as_failed!(error_message)
      assert app.app_status.failed?
      assert_equal error_message, app.error_message
    end
  end
end
