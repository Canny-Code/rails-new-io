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
#  user_id            :integer          not null
#  variant_id         :string
#
# Indexes
#
#  index_elements_on_command_line_value           (command_line_value)
#  index_elements_on_label                        (label)
#  index_elements_on_position                     (position)
#  index_elements_on_sub_group_id                 (sub_group_id)
#  index_elements_on_user_id                      (user_id)
#  index_elements_on_variant_type_and_variant_id  (variant_type,variant_id)
#
# Foreign Keys
#
#  sub_group_id  (sub_group_id => sub_groups.id)
#  user_id       (user_id => users.id)
#
class Element < ApplicationRecord
  include CommandLineValueGenerator
  include ElementVisibility

  before_save :set_command_line_value
  after_destroy :destroy_variant

  delegated_type :variant, types: %w[
    Element::RailsFlagCheckbox
    Element::CustomIngredientCheckbox
    Element::RadioButton
    Element::TextField
    Element::Unclassified
  ]

  belongs_to :sub_group
  belongs_to :user
  has_one :group, through: :sub_group

  validates :label, presence: true
  validate :unique_label_within_group_subgroup_and_user
  validates :variant_type, presence: true
  validates :variant_id, presence: true
  validate :variant_must_exist

  def self.null
    new(variant: Element::Null.new)
  end

  def variant
    super || Element::Null.new
  end

  def displayed?
    variant.displayed?
  end

  def cleaned_group_sub_group
    "#{sub_group.group.title}-#{sub_group.title}".downcase.gsub(/[^a-z0-9-]+/, "-")
  end

  private

  def destroy_variant
    variant.destroy if variant.present? && !variant.is_a?(Element::Null)
  end

  def variant_must_exist
    return unless variant_type && variant_id
    return if variant_type == "Element::Null"  # Allow null objects

    unless variant_type.constantize.exists?(id: variant_id)
      errors.add(:variant, "must exist")
    end
  end

  def set_command_line_value
    self.command_line_value = generate_command_line_value
  end

  def unique_label_within_group_subgroup_and_user
    return unless group

    duplicate = group.sub_groups
                    .where(id: sub_group_id) # Only check within the same subgroup
                    .joins(:elements)
                    .where.not(elements: { id: id })
                    .where(elements: { label: label, user_id: user_id })
                    .exists?

    if duplicate
      errors.add(:label, "must be unique within the group and subgroup for the same user")
    end
  end
end
