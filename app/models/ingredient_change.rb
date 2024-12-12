# == Schema Information
#
# Table name: ingredient_changes
#
#  id            :integer          not null, primary key
#  applied_at    :datetime
#  change_data   :json             not null
#  change_type   :string           not null
#  description   :text
#  error_message :text
#  success       :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer          not null
#
# Indexes
#
#  index_ingredient_changes_on_ingredient_id  (ingredient_id)
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id) ON DELETE => cascade
#
class IngredientChange < ApplicationRecord
  belongs_to :ingredient

  validates :change_type, presence: true,
    inclusion: { in: %w[template schema dependencies] }
  validates :change_data, presence: true

  def apply!
    return if applied_at.present?

    transaction do
      # Collect all changes in a hash
      updates = case change_type
      when "template"
        ingredient.update!(template_content: change_data["template_content"])
        {}
      when "schema"
        ingredient.update!(configures_with: change_data["configures_with"])
        {}
      when "dependencies"
        ingredient.update!(
          conflicts_with: change_data["conflicts_with"],
          requires: change_data["requires"]
        )
        {}
      end

      # Single update with merged attributes
      update!(updates.merge(
        applied_at: Time.current,
        success: true
      ))
    end
  rescue => e
    update!(
      applied_at: Time.current,
      success: false,
      error_message: e.message
    )
    raise e
  end
end
