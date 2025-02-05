require "test_helper"

class StatusStepsCalculatorTest < ActiveSupport::TestCase
  def setup
    @generated_app = generated_apps(:pending_app)
    @app_status = @generated_app.app_status
    @calculator = StatusStepsCalculator.new(@generated_app)
  end

  test "current step is pending when history is empty" do
    @app_status.update!(status_history: [])

    steps = @calculator.steps
    pending_step = steps.find { |step| step[:state] == :pending }

    assert pending_step[:current], "Pending step should be current when history is empty"
    assert_not pending_step[:completed], "Pending step should not be completed"

    non_pending_steps = steps.reject { |step| step[:state] == :pending }
    non_pending_steps.each do |step|
      assert_not step[:current], "#{step[:state]} step should not be current"
      assert_not step[:completed], "#{step[:state]} step should not be completed"
    end
  end
end
