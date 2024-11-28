# == Schema Information
#
# Table name: app_generation_log_entries
#
#  id               :integer          not null, primary key
#  level            :string           not null
#  message          :text             not null
#  metadata         :json
#  phase            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  generated_app_id :integer          not null
#
# Indexes
#
#  idx_on_generated_app_id_created_at_eac7d7a1a2         (generated_app_id,created_at)
#  index_app_generation_log_entries_on_generated_app_id  (generated_app_id)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id)
#
module AppGeneration
  class LogEntry < ApplicationRecord
    self.table_name = "app_generation_log_entries"

    belongs_to :generated_app

    enum :level, %w[ info warn error ].map { |level| [ level, level.to_s ] }.to_h
    enum :phase, AppStatus.states.map { |state| [ state, state.to_s ] }.to_h

    validates :message, presence: true
    validates :level, presence: true
    validates :phase, presence: true

    scope :chronological, -> { order(created_at: :asc) }
    scope :recent_first, -> { order(created_at: :desc) }
  end
end
