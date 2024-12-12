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
#  recipe_change_id :integer
#
# Indexes
#
#  index_app_changes_on_generated_app_id  (generated_app_id)
#  index_app_changes_on_recipe_change_id  (recipe_change_id)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id) ON DELETE => cascade
#  recipe_change_id  (recipe_change_id => recipe_changes.id) ON DELETE => cascade
#
class AppChange < ApplicationRecord
  belongs_to :generated_app
  belongs_to :recipe_change

  validates :configuration, presence: true

  def to_git_format
    {
      recipe_change_type: recipe_change.change_type,
      configuration: configuration,
      applied_at: applied_at&.iso8601,
      success: success,
      error_message: error_message
    }
  end

  def apply!
    return if applied_at.present?

    begin
      transaction do
        # Apply the recipe change to this specific app instance
        template_path = Rails.root.join("tmp", "templates", id.to_s)
        content = recipe_change.apply_to_app(generated_app, configuration)

        # Write and apply the template
        FileUtils.mkdir_p(File.dirname(template_path))
        File.write(template_path, content)

        pid = Process.spawn(
          { "DISABLE_SPRING" => "true" },
          "bin/rails app:template LOCATION=#{template_path}",
          chdir: generated_app.source_path
        )
        _, status = Process.wait2(pid)

        update!(
          applied_at: Time.current,
          success: status.success?,
          error_message: status.success? ? nil : "Template application failed"
        )
      ensure
        FileUtils.rm_f(template_path)
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
end
