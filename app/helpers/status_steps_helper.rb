module StatusStepsHelper
  def calculate_status_steps(generated_app)
    StatusStepsCalculator.call(generated_app)
  end
end
