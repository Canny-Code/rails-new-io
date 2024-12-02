module NotificationsHelper
  def safe_notification_url(notification)
    return "#" if notification.url.blank?

    # If it's an internal route starting with '/'
    return notification.url if notification.url.start_with?("/")

    # For external URLs, ensure they're properly formatted
    uri = URI.parse(notification.url)
    return "#" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    uri.to_s
  rescue URI::InvalidURIError
    "#"
  end
end
