class IngredientUiCreator
  def self.call(ingredient, page_title: "Your Custom Ingredients")
    new(ingredient, page_title).call
  end

  def initialize(ingredient, page_title)
    @ingredient = ingredient
    @page_title = page_title
  end

  def call
    ActiveRecord::Base.transaction do
      page = Page.find_by!(title: page_title)
      group = find_or_create_group(page)
      sub_group = find_or_create_sub_group(group)
      create_element(sub_group)
    end
  end

  private

  attr_reader :ingredient, :page_title

  def find_or_create_group(page)
    page.groups.find_or_create_by!(title: ingredient.category, behavior_type: "custom_ingredient_checkbox")
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
      variant: Element::CustomIngredientCheckbox.create!(
        checked: false,
        default: false,
        ingredient: ingredient
      )
    )
  end
end
