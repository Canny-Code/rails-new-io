class IngredientUiUpdater
  def self.call(ingredient)
    new(ingredient).call
  end

  def initialize(ingredient)
    @ingredient = ingredient
  end

  def call
    checkbox = ingredient.custom_ingredient_checkbox
    return unless checkbox

    element = checkbox.element
    return unless element

    old_sub_group = element.sub_group
    old_group = old_sub_group.group

    ActiveRecord::Base.transaction do
      if old_group.title != ingredient.category || old_sub_group.title != ingredient.sub_category
        move_element_to_new_group(element, old_group, old_sub_group)
      else
        update_element_attributes(element)
      end

      # Clean up empty sub_groups and groups
      if old_sub_group.elements.reload.empty?
        old_sub_group.destroy!

        old_group.reload
        old_group.destroy! if old_group.sub_groups.empty?
      end
    end
  end

  private

  def move_element_to_new_group(element, old_group, old_sub_group)
    page = old_group.page
    new_group = page.groups.find_or_create_by!(title: ingredient.category, behavior_type: "custom_ingredient_checkbox")
    new_sub_group = new_group.sub_groups.find_or_create_by!(title: ingredient.sub_category)

    element.update!(
      sub_group: new_sub_group,
      label: new_label_with_suffix(element.label),
      description: ingredient.description
    )
  end

  def update_element_attributes(element)
    element.update!(
      label: new_label_with_suffix(element.label),
      description: ingredient.description
    )
  end

  def new_label_with_suffix(old_label)
    if old_label =~ /\(.*\)/
      suffix = old_label.match(/\(.*\)/).to_s
      "#{ingredient.name} #{suffix}"
    else
      ingredient.name
    end
  end

  attr_reader :ingredient
end
