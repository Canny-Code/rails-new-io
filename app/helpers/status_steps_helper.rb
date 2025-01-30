module StatusStepsHelper
  def calculate_status_steps(generated_app)
    StatusStepsCalculator.call(generated_app)
  end


  def class_for_transition(state_sequence, step_from, step_to, current_index)
    from_index = state_sequence.index(step_from)
    to_index = state_sequence.index(step_to)
    current_index = current_index.to_i  # Convert nil to 0, keep integers as is

    return "bg-gray-300" if from_index.nil? || to_index.nil?

    if from_index < current_index && to_index <= current_index
      "bg-green-500"
    else
      "bg-gray-300"
    end
  end
end
