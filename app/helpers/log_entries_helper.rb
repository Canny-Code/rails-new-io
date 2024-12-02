module LogEntriesHelper
  def log_level_color(level)
    case level.to_sym
    when :error
      "bg-red-50"
    when :warn
      "bg-yellow-50"
    when :info
      "bg-white"
    else
      "bg-white"
    end
  end

  def rails_output?(log_entry)
    log_entry.metadata&.dig("is_rails_output")
  end
end
