# == Schema Information
#
# Table name: app_statuses
#
#  id               :integer          not null, primary key
#  completed_at     :datetime
#  error_message    :text
#  started_at       :datetime
#  status           :string           not null
#  status_history   :json
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  generated_app_id :integer          not null
#
# Indexes
#
#  index_app_statuses_on_generated_app_id  (generated_app_id)
#  index_app_statuses_on_status            (status)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id)
#
class AppStatus < ApplicationRecord
  belongs_to :generated_app

  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :generating
    state :pushing_to_github
    state :running_ci
    state :completed
    state :failed

    event :start_generation do
      transitions from: :pending, to: :generating
      after do
        update(started_at: Time.current)
        track_transition(:generating)
      end
    end

    event :start_github_push do
      transitions from: :generating, to: :pushing_to_github
      after { track_transition(:pushing_to_github) }
    end

    event :start_ci do
      transitions from: :pushing_to_github, to: :running_ci
      after { track_transition(:running_ci) }
    end

    event :complete do
      transitions from: [ :running_ci, :pushing_to_github ], to: :completed
      after do
        update(completed_at: Time.current)
        track_transition(:completed)
      end
    end

    event :fail do
      transitions from: [ :pending, :generating, :pushing_to_github, :running_ci ], to: :failed
      after do |error_message|
        update(
          completed_at: Time.current,
          error_message: error_message
        )
        track_transition(:failed)
      end
    end
  end

  private

  def track_transition(to_state)
    history_entry = {
      from: aasm.from_state,
      to: to_state,
      timestamp: Time.current
    }

    self.status_history = status_history.push(history_entry)
    save!
  end
end
