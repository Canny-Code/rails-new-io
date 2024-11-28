# frozen_string_literal: true

class NotificationBadge::Component < ApplicationComponent
  include Phlex::Rails::Helpers::TurboStreamFrom
  delegate :current_user, to: :helpers

  def initialize(user: nil)
    @user = user
  end

  def view_template
    user = @user || current_user
    return unless user

    turbo_stream_from [ :notification_badge, user.id ]

    a(id: "#{user.id}_notification_badge", href: "/notifications", class: "relative inline-flex items-center text-gray-400 hover:text-gray-500", data: { turbo_frame: "_top" }) do
      span(class: "sr-only") { "View notifications" }

      svg(class: "h-6 w-6", fill: "none", viewbox: "0 0 24 24", stroke: "currentColor") do |s|
        s.path(
          stroke_linecap: "round",
          stroke_linejoin: "round",
          stroke_width: "2",
          d: "M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
        )
      end

      if user.notifications.unread.any?
        span(class: "absolute -top-1 -right-1 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-red-100 bg-red-600 rounded-full") do
          plain user.notifications.unread.count
        end
      end
    end
  end
end
