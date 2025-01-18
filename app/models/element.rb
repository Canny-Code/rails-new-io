# == Schema Information
#
# Table name: elements
#
#  id                 :integer          not null, primary key
#  command_line_value :string
#  description        :text
#  image_path         :string
#  label              :string           not null
#  position           :integer
#  variant_type       :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  sub_group_id       :integer
#  variant_id         :string
#
# Indexes
#
#  index_elements_on_command_line_value           (command_line_value)
#  index_elements_on_label                        (label)
#  index_elements_on_position                     (position)
#  index_elements_on_sub_group_id                 (sub_group_id)
#  index_elements_on_variant_type_and_variant_id  (variant_type,variant_id)
#
# Foreign Keys
#
#  sub_group_id  (sub_group_id => sub_groups.id)
#
class Element < ApplicationRecord
  include CommandLineValueGenerator

  before_save :set_command_line_value

  delegated_type :variant, types: %w[
    Element::RailsFlagCheckbox
    Element::CustomIngredientCheckbox
    Element::RadioButton
    Element::TextField
    Element::Unclassified
  ], dependent: :destroy

  belongs_to :sub_group
  has_one :group, through: :sub_group

  validates :label, presence: true, uniqueness: { scope: :sub_group_id }
  validate :unique_label_within_group

  def self.null
    new(variant: Element::Null.new)
  end

  def variant
    super || Element::Null.new
  end

  def displayed?
    variant.displayed?
  end

  private

  def set_command_line_value
    self.command_line_value = generate_command_line_value
  end

  def unique_label_within_group
    return unless group

    duplicate = group.sub_groups.joins(:elements)
                    .where.not(elements: { id: id })
                    .where(elements: { label: label })
                    .exists?

    if duplicate
      errors.add(:label, "must be unique within the group")
    end
  end
end
