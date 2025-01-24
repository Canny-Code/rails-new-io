class IngredientUiDestroyer
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

      element = sub_group.elements.find_by(label: ingredient.name)
      return unless element

      # Delete the element
      element.destroy

      # If this was the last element in the sub_group, delete the sub_group
      if sub_group.elements.reload.empty?
        sub_group.destroy

        # If this was the last sub_group in the group, delete the group
        if group.sub_groups.reload.empty?
          group.destroy
        end
      end
    end
  end

  private

  attr_reader :ingredient
end
