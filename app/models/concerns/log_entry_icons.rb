module LogEntryIcons
  extend ActiveSupport::Concern

  def decorated_message
    simple_format("#{message_icons}#{message}")
  end

  private

  def message_icons
    case message.downcase
    when /starting app generation workflow/
      "🛤️ 🏗️ 🔄 "
    when /starting github repo creation/
      "🐙 🏗️ 🔄 "
    when /github repo .+ created successfully/
      "🐙 🏗️ ✅ "
    when /validating command/
      "🛤️ 🛡️ 🔄 "
    when /command validation successful/
      "🛤️ 🛡️ ✅ "
    when /created workspace directory/, /using existing app directory/
      "💻 📂 ✅ "
    when /preparing to execute command/
      "💻 🛠️ ✅ "
    when /system environment details/
      "💻 📈 🔍 "
    when /environment variables for command execution/
      "💻 📈 🔍 "
    when /command execution started/
      if message.include?("rails new")
        "🛤️ 🏗️ 🔄 "
      elsif message.include?("bundle install")
        "📦 🏗️ 🔄 "
      elsif message.include?("app:template")
        "🍱 🏗️ 🔄 "
      end
    when /rails app generation process finished successfully/
      "🛤️ 🏗️ ✅ "
    when /creating initial commit/
      "🐙 📝 🔄 "
    when /initial commit created successfully/
      "🐙 📝 ✅ "
    when /applying ingredients/
      "🍱 🏗️ 🔄 "
    when /applying ingredient: .+/
      "🍱 🍣 🔄 "
    when /committing ingredient changes/
      "🐙 🍣 📝 "
    when /ingredient .+ applied successfully/
      "🍱 🍣 ✅ "
    when /all ingredients applied successfully/
      "🍱 🏗️ ✅ "
    when /installing app dependencies/
      "📦 🏗️ 🔄 "
    when /dependencies installed successfully/
      "📦 🏗️ ✅ "
    when /starting github push/
      "🐙 ⬆️ 🔄 "
    when /github push completed successfully/
      "🐙 ⬆️ ✅ "
    when /starting ci run/
      "🐙 ⚙️ 🔄 "
    when /app generation completed successfully/
      "🛤️ 🏗️ ✅ "
    else
      ""
    end
  end
end
