module LogEntryIcons
  extend ActiveSupport::Concern

  def decorated_message
    "#{message_icons}#{message}"
  end

  private

  def message_icons
    case message.downcase
    when /starting app generation/
      "🐙 🛤️ 🏗️ 🪄 🔄 "
    when /creating repository/
      "🐙 🏗️ 🔄 "
    when /repository created successfully/
      "🐙 🏗️ ✅ "
    when /validating command/
      "🤖 🔍 🔄 "
    when /command validation successful/
      "🤖 🔍 ✅ "
    when /created temporary directory/
      "📂 🏗️ ✅ "
    when /system environment details/
      "💻 📈 "
    when /environment variables for command execution/
      "🔧 ⚙️ "
    when /rails app generation process started/
      "🛤️ 🏗️ 🔄 "
    when /starting github push/
      "🐙 ⬆️ 🔄 "
    when /app generation completed successfully/
      "🐙 🛤️ 🏗️ 🪄 ✅ "
    else
      ""
    end
  end
end
