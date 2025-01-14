# == Schema Information
#
# Table name: element_checkboxes
#
#  id           :integer          not null, primary key
#  checked      :boolean
#  default      :boolean
#  display_when :string           default("checked")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

# | default | checked | display_when | Result                                                            |
# |---------|---------|--------------|-------------------------------------------------------------------|
# | false   | false   | "checked"    | Initially and currently unchecked, outputs nothing when unchecked |
# | false   | false   | "unchecked"  | Initially and currently unchecked, outputs value when unchecked   |
# | false   | true    | "checked"    | Initially unchecked but currently checked, outputs value          |
# | false   | true    | "unchecked"  | Initially unchecked but currently checked, outputs nothing        |
# | true    | false   | "checked"    | Initially checked but currently unchecked, outputs nothing        |
# | true    | false   | "unchecked"  | Initially checked but currently unchecked, outputs value          |
# | true    | true    | "checked"    | Initially and currently checked, outputs value                    |
# | true    | true    | "unchecked"  | Initially and currently checked, outputs nothing                  |
#
# Examples:
#
# A checkbox for "--no-test"
# Element::Checkbox.create!(
#   default: true,           # Starts checked
#   display_when: "unchecked", # Only outputs when unchecked
#   # When unchecked, it would output "--no-test"
# )

# # A checkbox for "--debug"
# Element::Checkbox.create!(
#   default: false,          # Starts unchecked
#   display_when: "checked", # Only outputs when checked
#   # When checked, it would output "--debug"
# )


class Element::Checkbox < ApplicationRecord
  has_one :element, as: :variant

  def displayed?
    true
  end
end
