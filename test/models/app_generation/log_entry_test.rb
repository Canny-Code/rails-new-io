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
#  generated_app_id  (generated_app_id => generated_apps.id) ON DELETE => cascade
#
require "test_helper"

module AppGeneration
  class LogEntryTest < ActiveSupport::TestCase
    def setup
      @generated_app = generated_apps(:blog_app)
      @log_entry = LogEntry.new(
        generated_app: @generated_app,
        level: :info,
        phase: :pending,
        message: "Starting app generation"
      )
    end

    test "valid log entry" do
      assert @log_entry.valid?
    end

    test "requires message" do
      @log_entry.message = nil
      assert_not @log_entry.valid?
    end

    test "requires valid level" do
      assert_raises(ArgumentError, "'invalid' is not a valid level") do
        @log_entry.level = :invalid
      end
    end

    test "requires valid phase" do
      assert_raises(ArgumentError, "'invalid' is not a valid phase") do
        @log_entry.phase = :invalid
      end
    end

    test "supports all levels" do
      %i[info warn error].each do |level|
        @log_entry.level = level
        assert @log_entry.valid?
        assert @log_entry.public_send("#{level}?")
      end
    end

    test "supports all phases" do
      %i[pending generating pushing_to_github running_ci completed failed].each do |phase|
        @log_entry.phase = phase
        assert @log_entry.valid?
        assert @log_entry.public_send("#{phase}?")
      end
    end
  end
end
