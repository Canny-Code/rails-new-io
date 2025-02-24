# frozen_string_literal: true

module GroupBehavior
  extend ActiveSupport::Concern

  included do
    attribute :behavior_type, :string, default: "none"
  end

  def stimulus_attributes
    case behavior_type
    when "database_choice"
      {
        controller: "radio-button-choice",
        "radio-button-choice-generated-output-outlet": "#database-choice",
        "output-prefix": "-d"
      }
    when "javascript_radio_button"
      {
        controller: "radio-button-choice",
        "radio-button-choice-generated-output-outlet": "#javascript-choice",
        "output-prefix": "-j"
      }
    when "css_radio_button"
      {
        controller: "radio-button-choice",
        "radio-button-choice-generated-output-outlet": "#css-choice",
        "output-prefix": "-c"
      }
    else
      {}
    end
  end
end
