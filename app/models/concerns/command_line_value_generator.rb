module CommandLineValueGenerator
  extend ActiveSupport::Concern

  def generate_command_line_value
    if sub_group.group.behavior_type == "database_choice"
      generate_database_choice_command_line_value
    elsif sub_group.group.behavior_type == "custom_ingredient_checkbox"
      label
    else
      generate_generic_checkbox_command_line_value
    end
  end

  def generate_generic_checkbox_command_line_value
    override_map = {
      "Run bundle install?" => "--skip-bundle",
      "Include `.keep` files?" => "--skip-keep"
    }

    # Handle override cases first
    return override_map[label] if override_map.key?(label)

    # Remove question mark and strip first word and any extra spaces
    clean_label = label
      .gsub(/\?$/, "")                    # Remove trailing question mark
      .sub(/^(Add|Include|Use)\s+/, "")   # Remove specific leading words
      .gsub(/^[`\s]+|[`\s]+$/, "")        # Remove leading/trailing backticks and spaces
      .gsub(/\s+Mode/, "")                # Remove "Mode" word

    # Convert to kebab-case and lowercase
    kebab_term = clean_label
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
      .gsub(/([a-z\d])([A-Z])/, '\1-\2')
      .downcase
      .gsub(/[\s._]/, "-")
      .gsub(/^\./, "")                    # Remove leading dot if present

    "--skip-#{kebab_term}".sub("skip-skip", "skip")
  end

  def generate_database_choice_command_line_value
    name = label.downcase

    if name.include?("(")
      base, variant = name.split("(").map(&:strip)
      variant = variant.gsub(/\)/, "").strip

      case base
      when "mariadb"
        "mariadb-#{variant.downcase}"
      else
        "#{base}-#{variant.downcase}"
      end
    else
      case name
      when "postgresql"
        "postgresql"
      when "mysql"
        "mysql"
      when "sqlite"
        "sqlite3"
      when "trilogy"
        "trilogy"
      else
        name.gsub(/[^a-z0-9-]/, "")
      end
    end
  end
end
