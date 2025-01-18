class IngredientUiUpdater
  def self.call(ingredient)
    new(ingredient).call
  end

  def initialize(ingredient)
    @ingredient = ingredient
  end

  def call
    ActiveRecord::Base.transaction do
      page = Page.find_by!(title: "Your Custom Ingredients")
      group = page.groups.find_by(title: ingredient.category)
      return unless group

      sub_group = group.sub_groups.find_by(title: "Default")
      return unless sub_group

      element = sub_group.elements
                        .joins("INNER JOIN element_custom_ingredient_checkboxes ON element_custom_ingredient_checkboxes.id = elements.variant_id")
                        .where(variant_type: "Element::CustomIngredientCheckbox")
                        .where("element_custom_ingredient_checkboxes.ingredient_id = ?", ingredient.id)
                        .first
      return unless element

      # Update the element's attributes
      element.update!(
        label: ingredient.name,
        description: ingredient.description
      )

      # If the category changed, we need to move the element to the correct group
      if element.sub_group.group.title != ingredient.category
        new_group = page.groups.find_or_create_by!(title: ingredient.category, behavior_type: "custom_ingredient_checkbox")
        new_sub_group = new_group.sub_groups.find_or_create_by!(title: "Default")

        # Move the element to the new sub_group
        element.update!(sub_group: new_sub_group)

        # Clean up empty groups/sub_groups
        old_sub_group = sub_group
        old_group = group

        if old_sub_group.elements.reload.empty?
          old_sub_group.destroy

          if old_group.sub_groups.reload.empty?
            old_group.destroy
          end
        end
      end
    end
  end

  private

  attr_reader :ingredient
end
