class IngredientUiCreator
  def self.call(ingredient)
    new(ingredient).call
  end

  def initialize(ingredient)
    @ingredient = ingredient
  end

  def call
    ActiveRecord::Base.transaction do
      page = Page.find_by!(title: "Your Custom Ingredients")
      group = find_or_create_group(page)
      sub_group = find_or_create_sub_group(group)
      create_element(sub_group)
    end
  end

  private

  attr_reader :ingredient

  def find_or_create_group(page)
    page.groups.find_or_create_by!(title: ingredient.category)
  end

  def find_or_create_sub_group(group)
    group.sub_groups.find_or_create_by!(title: "Default")
  end

  def create_element(sub_group)
    last_position = sub_group.elements.maximum(:position) || -1

    sub_group.elements.create!(
      label: ingredient.name,
      description: ingredient.description,
      position: last_position + 1,
      variant: Element::Checkbox.create!(
        checked: false,
        display_when: "checked"
      )
    )
  end
end
