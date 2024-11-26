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
