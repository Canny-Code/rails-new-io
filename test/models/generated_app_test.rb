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
end
