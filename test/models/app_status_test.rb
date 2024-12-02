# == Schema Information
#
# Table name: app_statuses
#
#  id               :integer          not null, primary key
#  completed_at     :datetime
#  error_message    :text
#  started_at       :datetime
#  status           :string           not null
#  status_history   :json
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  generated_app_id :integer          not null
#
# Indexes
#
#  index_app_statuses_on_generated_app_id  (generated_app_id)
#  index_app_statuses_on_status            (status)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id)
#
require "test_helper"

class AppStatusTest < ActiveSupport::TestCase
  def setup
    @generated_app = generated_apps(:blog_app)
    @pending_status = app_statuses(:pending_status)
  end

  test "initial state is pending" do
    status = AppStatus.create!(generated_app: @generated_app)
    assert status.pending?
  end

  test "follows happy path state transitions" do
    status = AppStatus.create!(generated_app: @generated_app)
    assert status.pending?
    assert_nil status.started_at

    # First transition
    status.start_github_repo_creation!
    assert_equal "creating_github_repo", status.status
    assert_nil status.started_at

    # Second transition
    status.start_generation!
    assert_equal "generating", status.status
    assert_not_nil status.started_at

    # Push to GitHub
    status.start_github_push!
    assert_equal "pushing_to_github", status.status

    # Start CI
    status.start_ci!
    assert_equal "running_ci", status.status

    # Complete
    status.complete!
    assert_equal "completed", status.status
    assert_not_nil status.completed_at

    # Verify we can't skip states
    [
      {
        from: :pending,
        invalid_transitions: [ :start_generation!, :start_github_push!, :start_ci!, :complete! ]
      },
      {
        from: :creating_github_repo,
        invalid_transitions: [ :start_github_push!, :start_ci!, :complete! ]
      },
      {
        from: :generating,
        invalid_transitions: [ :start_ci!, :complete! ]
      },
      {
        from: :pushing_to_github,
        invalid_transitions: [ :complete! ]
      }
    ].each do |test_case|
      test_status = AppStatus.create!(generated_app: @generated_app)

      # Move to the starting state if not pending
      unless test_case[:from] == :pending
        case test_case[:from]
        when :creating_github_repo
          test_status.start_github_repo_creation!
        when :generating
          test_status.start_github_repo_creation!
          test_status.start_generation!
        when :pushing_to_github
          test_status.start_github_repo_creation!
          test_status.start_generation!
          test_status.start_github_push!
        end
      end

      test_case[:invalid_transitions].each do |invalid_transition|
        assert_raises(AASM::InvalidTransition, "Should not allow #{invalid_transition} from #{test_case[:from]} state") do
          test_status.send(invalid_transition)
        end
      end
    end
  end

  test "can fail from any state" do
    states = [ :pending, :creating_github_repo, :generating, :pushing_to_github, :running_ci ]
    error_message = "Something went wrong"

    states.each do |state|
      status = AppStatus.create!(generated_app: @generated_app)

      # Move to the target state
      case state
      when :creating_github_repo
        status.start_github_repo_creation!
      when :generating
        status.start_github_repo_creation!
        status.start_generation!
      when :pushing_to_github
        status.start_github_repo_creation!
        status.start_generation!
        status.start_github_push!
      when :running_ci
        status.start_github_repo_creation!
        status.start_generation!
        status.start_github_push!
        status.start_ci!
      end

      status.fail!(error_message)
      assert status.failed?
      assert_equal error_message, status.error_message
      assert_not_nil status.completed_at
    end
  end

  test "tracks status history" do
    status = AppStatus.create!(generated_app: @generated_app)

    status.start_github_repo_creation!
    status.start_generation!
    status.fail!("Error occurred")

    assert_equal 3, status.status_history.size

    first_transition = status.status_history.first
    assert_equal "pending", first_transition["from"]
    assert_equal "creating_github_repo", first_transition["to"]
    assert_not_nil first_transition["timestamp"]

    second_transition = status.status_history.second
    assert_equal "creating_github_repo", second_transition["from"]
    assert_equal "generating", second_transition["to"]
    assert_not_nil second_transition["timestamp"]
  end

  test "belongs to generated app" do
    assert_respond_to @pending_status, :generated_app
    assert_equal @generated_app, @pending_status.generated_app
  end

  test ".states returns all possible states" do
    expected_states = %i[pending creating_github_repo generating pushing_to_github running_ci completed failed]
    assert_equal expected_states, AppStatus.states
  end

  test "restart transitions from failed to pending" do
    app_status = app_statuses(:failed_api_status)
    assert_equal "failed", app_status.status

    app_status.restart!

    assert_equal "pending", app_status.status
    assert_nil app_status.error_message
    assert_includes app_status.status_history, {
      "from" => "failed",
      "to" => "pending",
      "timestamp" => app_status.status_history.last["timestamp"]
    }
  end

  test "restart cannot transition from non-failed states" do
    app_status = app_statuses(:completed_api_status)
    assert_equal "completed", app_status.status

    assert_raises(AASM::InvalidTransition) do
      app_status.restart!
    end
  end

  test "follows github repo creation path state transitions" do
    status = AppStatus.create!(generated_app: @generated_app)
    assert_nil status.started_at

    status.start_github_repo_creation!
    assert status.creating_github_repo?
    assert_nil status.started_at

    status.start_generation!
    assert status.generating?
    assert_not_nil status.started_at
  end

  test "can fail from creating_github_repo state" do
    status = AppStatus.create!(generated_app: @generated_app)
    error_message = "Failed to create GitHub repository"

    status.start_github_repo_creation!
    assert status.creating_github_repo?

    status.fail!(error_message)
    assert status.failed?
    assert_equal error_message, status.error_message
    assert_not_nil status.completed_at
  end

  test "tracks status history through github repo creation" do
    status = AppStatus.create!(generated_app: @generated_app)

    status.start_github_repo_creation!
    status.start_generation!
    status.fail!("Error occurred")

    assert_equal 3, status.status_history.size

    first_transition = status.status_history.first
    assert_equal "pending", first_transition["from"]
    assert_equal "creating_github_repo", first_transition["to"]
    assert_not_nil first_transition["timestamp"]

    second_transition = status.status_history.second
    assert_equal "creating_github_repo", second_transition["from"]
    assert_equal "generating", second_transition["to"]
    assert_not_nil second_transition["timestamp"]
  end

  test "status transitions match log entry phases" do
    status = AppStatus.create!(generated_app: @generated_app)

    # Create a logger to simulate the real process
    logger = AppGeneration::Logger.new(@generated_app)

    # Create initial log entry (normally done by Buffer)
    AppGeneration::LogEntry.create!(
      generated_app: @generated_app,
      level: :info,
      message: "Initializing Rails application generation...",
      metadata: { stream: :stdout },
      phase: status.status,
      entry_type: "rails_output"
    )

    # Simulate the complete generation process with logging
    status.start_github_repo_creation!
    logger.info("Starting GitHub repo creation")

    status.start_generation!
    logger.info("Starting generation")

    status.start_github_push!
    logger.info("Starting GitHub push")

    status.start_ci!
    logger.info("Starting CI")

    status.complete!
    logger.info("Completed successfully")

    # Get unique phases in order of creation
    actual_phases = @generated_app.log_entries.order(:created_at).pluck(:phase).uniq
    expected_phases = %w[pending creating_github_repo generating pushing_to_github running_ci completed]

    assert_equal expected_phases, actual_phases,
      "Log entry phases should match status transitions"
  end
end
