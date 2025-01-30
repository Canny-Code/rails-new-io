class StatusStepsCalculator
  def self.call(generated_app)
    new(generated_app).call
  end

  def initialize(generated_app)
    @generated_app = generated_app
    @app_status = generated_app.app_status
    @current_state = @app_status.status.to_sym
    @state_sequence = AppStatus.state_sequence
    @history = @app_status.status_history
  end

  def call
    {
      current_state: @current_state,
      state_sequence: @state_sequence,
      history: @history,
      current_index: calculate_current_index,
      steps: calculate_steps
    }
  end

  private

  def calculate_current_index
    if @current_state == :failed
      last_state = @history.last&.dig("from")&.to_sym
      @state_sequence.index(last_state)
    else
      @state_sequence.index(@current_state)
    end
  end

  def calculate_steps
    AppStatus.states.reject do |state|
      (state == :failed || state == :completed) && state != @current_state
    end.each_with_index.map do |state, index|
      {
        state: state,
        number: index + 1,
        completed: step_passed?(state)
      }
    end
  end

  def step_passed?(state)
    if @current_state == :completed
      true
    elsif @current_state == :failed
      false
    else
      @history.any? { |transition| transition["from"] == state.to_s } ||
        (state == :pending && @current_state != :pending)
    end
  end
end
