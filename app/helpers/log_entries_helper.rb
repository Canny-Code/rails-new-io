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
end
