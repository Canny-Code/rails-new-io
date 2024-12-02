# == Schema Information
#
# Table name: app_generation_log_entries
#
#  id               :integer          not null, primary key
#  entry_type       :string
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
#  index_app_generation_log_entries_on_entry_type        (entry_type)
#  index_app_generation_log_entries_on_generated_app_id  (generated_app_id)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id)
#
module AppGeneration
  class LogEntry < ApplicationRecord
    include LogEntryIcons
    include ActionView::Helpers::TextHelper

    self.table_name = "app_generation_log_entries"

    after_commit -> {
      stream_name = "#{generated_app.to_gid}:app_generation_log_entries"

      Turbo::StreamsChannel.broadcast_prepend_to(
        stream_name,
        target: "app_generation_log_entries",
        partial: "app_generation/log_entries/log_entry",
        locals: { log_entry: self }
      )
    }, on: :create

    after_commit -> {
      stream_name = "#{generated_app.to_gid}:app_generation_log_entries"

      Turbo::StreamsChannel.broadcast_replace_to(
        stream_name,
        target: "log_entry_#{id}",
        partial: "app_generation/log_entries/log_entry",
        locals: { log_entry: self }
      )
    }, on: :update

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
