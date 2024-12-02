module StatusStepsHelper
  def calculate_status_steps(generated_app)
    StatusStepsCalculator.call(generated_app)
  end


  def class_for_transition(state_sequence, step_from, step_to, current_index)
    if state_sequence.index(step_from) < current_index &&
      state_sequence.index(step_to) <= current_index
     "bg-green-500"
    else
     "bg-gray-300"
    end
  end
end
