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
#  generated_app_id  (generated_app_id => generated_apps.id) ON DELETE => cascade
#
class AppStatus < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :generated_app, touch: true

  validates :status, presence: true
  validates :generated_app, presence: true, uniqueness: true

  after_update :broadcast_status_change, if: :saved_change_to_status?
  after_save :notify_status_change, if: :saved_change_to_status?

  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :creating_github_repo
    state :generating
    state :pushing_to_github
    state :running_ci
    state :completed
    state :failed

    after_all_transitions do
      track_transition
    end

    event :start_github_repo_creation do
      transitions from: :pending, to: :creating_github_repo
    end

    event :start_generation do
      transitions from: :creating_github_repo, to: :generating
      after do
        update(started_at: Time.current)
      end
    end

    event :start_github_push do
      transitions from: :generating, to: :pushing_to_github
    end

    event :start_ci do
      transitions from: :pushing_to_github, to: :running_ci
    end

    event :complete do
      transitions from: :running_ci, to: :completed
      after do
        update(completed_at: Time.current)
      end
    end

    event :fail do
      transitions from: [ :pending, :creating_github_repo, :generating, :pushing_to_github, :running_ci ], to: :failed
      after do |error_message|
        update(
          completed_at: Time.current,
          error_message: error_message
        )
      end
    end

    event :restart do
      transitions from: [ :generating, :failed ], to: :pending
      after do
        update(error_message: nil)
      end
    end
  end

  class << self
    def states
      aasm.states.map(&:name)
    end

    def state_sequence
      states - [ :failed ]
    end

    def events
      aasm.events.map { |event| "#{event.name}!" }
    end

    def state_predicates
      aasm.states.map { |state| "#{state.name}?" }
    end
  end


  def broadcast_status_steps
    channel = "#{generated_app.to_gid}:app_status"

    Turbo::StreamsChannel.broadcast_replace_to(
      channel,
      target: "status_steps_content",
      partial: "shared/status_steps",
      locals: { generated_app: generated_app }
    )
  end

  private

  def track_transition
    history_entry = {
      from: aasm.from_state,
      to: aasm.to_state,
      timestamp: Time.current
    }

    self.status_history = status_history.push(history_entry)
    generated_app.touch(:last_build_at)
    broadcast_status_steps
  end

  def broadcast_status_change
    generated_app.broadcast_replace_to(
      [ :generated_app, generated_app.user_id ],
      target: "generated_app_#{generated_app.id}",
      partial: "generated_apps/generated_app",
      locals: { generated_app: generated_app }
    )

    generated_app.broadcast_replace_to(
      [ :notification_badge, generated_app.user_id ],
      target: "#{generated_app.user_id}_notification_badge",
      content: ApplicationController.render(
        NotificationBadge::Component.new(user: generated_app.user),
        layout: false
      )
    )
  end

  def notify_status_change
    AppStatusChangeNotifier.with(
      generated_app_id: generated_app.id,
      generated_app_name: generated_app.name,
      old_status: status_before_last_save,
      new_status: status
    ).deliver(generated_app.user)
  end
end
