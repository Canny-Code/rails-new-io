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
    else
      {}
    end
  end
end
