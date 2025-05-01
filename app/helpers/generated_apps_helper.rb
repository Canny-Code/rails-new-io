module GeneratedAppsHelper
  def status_color(status)
    case status
    when "pending"
      "bg-yellow-100 text-yellow-800"
    when "processing"
      "bg-blue-100 text-blue-800"
    when "completed"
      "bg-green-100 text-green-800"
    when "failed"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def render_onboarding_explanation(step)
    return unless step.present?

    valid_steps = (1..10).to_a
    return unless valid_steps.include?(step.to_i)

    render "shared/onboarding/#{step}/explanation"
  end

  def render_onboarding_sidebar(step)
    return unless step.present?

    valid_steps = (1..10).to_a
    return unless valid_steps.include?(step.to_i)

    render "shared/onboarding/#{step}/sidebar"
  end
end
