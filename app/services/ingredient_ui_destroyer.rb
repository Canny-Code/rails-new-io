class IngredientUiDestroyer
  def self.call(ingredient)
    new(ingredient).call
  end

  def initialize(ingredient)
    @ingredient = ingredient
  end

  def call
    ActiveRecord::Base.transaction do
      checkbox = Element::CustomIngredientCheckbox.find_by(ingredient_id: ingredient.id)
      return unless checkbox

      element = checkbox.element
      return unless element

      sub_group = element.sub_group
      group = sub_group.group

      # Destroy the element (this will also destroy the checkbox due to delegated_type)
      element.destroy

      # Clean up empty ancestors
      if sub_group.elements.reload.empty?
        sub_group.destroy

        if group.sub_groups.reload.empty?
          group.destroy
        end
      end
    end
  end

  private

  attr_reader :ingredient
end
