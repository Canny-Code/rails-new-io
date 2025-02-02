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
      current_index: current_index,
      steps: steps
    }
  end

  def current_index
    @current_index ||= calculate_current_index
  end

  def steps
    @steps ||= calculate_steps
  end

  private

  def calculate_current_index
    if @current_state.in?(state_sequence)
      state_sequence.index(@current_state)
    elsif @current_state == :failed
      state_sequence.index(@history.last["to"].to_sym)
    else
      state_sequence.index(@current_state)
    end
  end

  def calculate_steps
    return completed_steps if @current_state == :completed

    state_sequence.map.with_index do |state, index|
      completed = @history.any? { |transition| transition["from"] == state.to_s }
      current = if @history.empty?
        state == :pending
      else
        state.to_s == @history.last["to"]
      end

      {
        state:,
        number: index + 1,
        completed:,
        current:
      }
    end
  end

  def completed_steps
    state_sequence.map.with_index do |state, index|
      {
        state:,
        number: index + 1,
        completed: true,
        current: false
      }
    end
  end

  def state_sequence
    @state_sequence ||= AppStatus.state_sequence
  end
end
