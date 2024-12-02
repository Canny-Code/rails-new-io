require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @other_user = users(:jane)
    @notification = noticed_notifications(:notification_one)
    # Ensure the notification's event has the correct params structure
    @notification.event.update!(
      params: {
        generated_app_id: generated_apps(:blog_app).id,
        generated_app_name: "personal-blog",
        old_status: "failed",
        new_status: "pending"
      }
    )
    sign_in @user
  end

  test "should get index" do
    get notifications_path
    assert_response :success
  end

  test "should redirect index when not logged in" do
    sign_out @user
    get notifications_path
    assert_redirected_to root_path
  end

  test "should mark notification as read" do
    assert_changes -> { @notification.reload.read_at } do
      patch notification_path(@notification),
      headers: { "Accept": "text/vnd.turbo-stream.html" },
      xhr: true
    end
    assert_response :success
  end

  test "should redirect to notifications path for html request" do
    patch notification_path(@notification)
    assert_redirected_to notifications_path
  end

  test "should not allow access to other user's notifications" do
    other_user = users(:jane)
    other_notification = noticed_notifications(:notification_two)
    other_notification.update(recipient: other_user)


    patch notification_path(other_notification)
    assert_redirected_to notifications_path, alert: "Notification not found"
  end
end
