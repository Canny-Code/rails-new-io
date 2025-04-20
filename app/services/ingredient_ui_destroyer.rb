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
      if checkbox
        element = checkbox.element
        if element
          sub_group = element.sub_group
          group = sub_group.group

          # First destroy the element
          element.destroy

          # Then destroy the checkbox
          checkbox.destroy

          # Clean up empty ancestors
          if sub_group.elements.reload.empty?
            sub_group.destroy

            if group.sub_groups.reload.empty?
              group.destroy
            end
          end
        end
      end

      # Finally destroy the ingredient
      ingredient.destroy
    end
  end

  private

  attr_reader :ingredient
end
