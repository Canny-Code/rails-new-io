# == Schema Information
#
# Table name: app_changes
#
#  id               :integer          not null, primary key
#  applied_at       :datetime
#  configuration    :json
#  error_message    :text
#  success          :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  generated_app_id :integer          not null
#  ingredient_id    :integer          not null
#
# Indexes
#
#  index_app_changes_on_generated_app_id  (generated_app_id)
#  index_app_changes_on_ingredient_id     (ingredient_id)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id) ON DELETE => cascade
#  ingredient_id     (ingredient_id => ingredients.id) ON DELETE => cascade
#
class AppChange < ApplicationRecord
  belongs_to :generated_app
  belongs_to :ingredient

  validates :configuration, presence: true

  def to_git_format
    {
      ingredient_name: ingredient.name,
      configuration: configuration,
      applied_at: applied_at&.iso8601,
      success: success,
      error_message: error_message
    }
  end

  def apply!
    return if applied_at.present?

    transaction do
      begin
        content = ingredient.configuration_for(configuration)
        # Apply the template here
        update!(
          applied_at: Time.current,
          success: true
        )
      rescue => e
        update!(
          applied_at: Time.current,
          success: false,
          error_message: e.message
        )
        raise
      end
    end
  end
end
