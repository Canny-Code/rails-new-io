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
    assert_nil status.started_at

    status.start_generation!
    assert status.generating?
    assert_not_nil status.started_at

    status.start_github_push!
    assert status.pushing_to_github?

    status.start_ci!
    assert status.running_ci?

    status.complete!
    assert status.completed?
    assert_not_nil status.completed_at
  end

  test "can fail from any state" do
    states = [ :pending, :generating, :pushing_to_github, :running_ci ]
    error_message = "Something went wrong"

    states.each do |state|
      status = AppStatus.create!(generated_app: @generated_app)

      # Move to the target state
      case state
      when :generating
        status.start_generation!
      when :pushing_to_github
        status.start_generation!
        status.start_github_push!
      when :running_ci
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

    status.start_generation!
    status.start_github_push!
    status.fail!("Error occurred")

    assert_equal 3, status.status_history.size

    first_transition = status.status_history.first
    assert_equal "pending", first_transition["from"]
    assert_equal "generating", first_transition["to"]
    assert_not_nil first_transition["timestamp"]
  end

  test "belongs to generated app" do
    assert_respond_to @pending_status, :generated_app
    assert_equal @generated_app, @pending_status.generated_app
  end

  test ".states returns all possible states" do
    expected_states = %i[pending generating pushing_to_github running_ci completed failed]
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
end
