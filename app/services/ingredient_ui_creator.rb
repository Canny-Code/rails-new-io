class IngredientUiCreationError < StandardError; end
class IngredientUiCreator
  def self.call(ingredient, page_title: "Your Custom Ingredients", position: nil)
    new(ingredient, page_title).call
  end

  def initialize(ingredient, page_title)
    @ingredient = ingredient
    @page_title = page_title
  end

  def call
    ActiveRecord::Base.transaction do
      begin
        page = Page.find_by!(title: page_title)
        group = find_or_create_group(page)
        sub_group = find_or_create_sub_group(group)
        create_element(sub_group)
      rescue StandardError => e
        Rails.logger.error("Unexpected error creating ingredient UI: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
        raise IngredientUiCreationError.new("Unexpected error creating ingredient UI: #{e.message}")
      end
    end
  end

  private

  attr_reader :ingredient, :page_title

  def find_or_create_group(page)
    if existing_group = page.groups.find_by(title: ingredient.category)
      return existing_group
    end

    position = 0 if page.groups.empty?
    position = position || page.groups.maximum(:position) + 1

    page.groups.create!(
      title: ingredient.category,
      behavior_type: "custom_ingredient_checkbox",
      position: position
    )
  end

  def find_or_create_sub_group(group)
    group.sub_groups.find_or_create_by!(title: ingredient.sub_category)
  end

  def create_element(sub_group)
    last_position = sub_group.elements.maximum(:position) || -1

    sub_group.elements.create!(
      user: Current.user,
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
