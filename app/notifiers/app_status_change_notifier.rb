class AppStatusChangeNotifier < Noticed::Event
  deliver_by :action_cable do |config|
    config.channel = "Noticed::NotificationChannel"
    config.stream = -> { recipient }
    config.message = -> { params.merge(user_id: recipient.id) }
  end

  notification_methods do
    def message
      I18n.t("notifiers.app_status_change_notifier.message",
        app_name: params[:generated_app_name],
        old_status: params[:old_status],
        new_status: params[:new_status])
    end

    def url
      Rails.application.routes.url_helpers.generated_app_path(params[:generated_app_id])
    end

    # private

    # def action_cable_format
    #   {
    #     # title: "App Status Change",
    #     # body: message,
    #     url: url,
    #     generated_app_name: params[:generated_app_name],
    #     generated_app_id: params[:generated_app_id],
    #     old_status: params[:old_status],
    #     new_status: params[:new_status]
    #   }
    # end
  end
end
