class IngredientUiUpdater
  def self.call(ingredient)
    new(ingredient).call
  end

  def initialize(ingredient)
    @ingredient = ingredient
    @groups_to_check = Set.new
  end

  def call
    page = Page.find_by(title: "Your Custom Ingredients")
    return unless page

    elements_to_process = Element.joins(:sub_group)
                    .joins("INNER JOIN groups ON groups.id = sub_groups.group_id")
                    .joins("INNER JOIN element_custom_ingredient_checkboxes ON element_custom_ingredient_checkboxes.id = elements.variant_id")
                    .where(groups: { page_id: page.id })
                    .where(variant_type: "Element::CustomIngredientCheckbox")
                    .where(element_custom_ingredient_checkboxes: { ingredient_id: ingredient.id })
                    .includes(sub_group: :group)  # Eager load associations
                    .to_a
    return if elements_to_process.empty?

    ActiveRecord::Base.transaction do
      elements_to_process.each do |element|
        new_label = if element.label =~ /\(.*\)/
                     suffix = element.label.match(/\(.*\)/).to_s
                     "#{ingredient.name} #{suffix}"
        else
                     ingredient.name
        end

        old_sub_group = element.sub_group
        old_group = old_sub_group.group

        needs_move = !old_group.title.eql?(ingredient.category)

        if needs_move
          move_element_to_new_group(element, old_group, old_sub_group, new_label, page)
        else
          handle_unchanged_category(element, new_label)
        end
      end

      # Clean up empty groups and their sub_groups

      groups_to_check.each do |group|
        begin
          group.reload
          group.sub_groups.each do |sub_group|
            if sub_group.elements.count.zero?
              sub_group.destroy!
            end
          end
          group.reload

          group.destroy! if group.sub_groups.count.zero?
        rescue ActiveRecord::RecordNotFound => e
          next
        end
      end
    end
  end

  private

  def move_element_to_new_group(element, old_group, old_sub_group, new_label, page)
    new_group = page.groups.find_or_create_by!(title: ingredient.category, behavior_type: "custom_ingredient_checkbox")
    new_sub_group = new_group.sub_groups.find_or_create_by!(title: old_sub_group.title)

    # Track for cleanup
    groups_to_check << old_group

    # Move the element and update its attributes
    element.update!(
      sub_group: new_sub_group,
      label: new_label,
      description: ingredient.description
    )
  end

  def handle_unchanged_category(element, new_label)
    update_attributes_only(element, new_label)
  end

  def update_attributes_only(element, new_label)
    element.update!(
      label: new_label,
      description: ingredient.description
    )
  end

  attr_reader :ingredient, :groups_to_check
end
