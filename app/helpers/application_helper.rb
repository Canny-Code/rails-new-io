module ApplicationHelper
  include Pagy::Frontend

  def full_title
    if content_for?(:title)
      "#{content_for(:title)} | #{Rails.application.config.application_name}"
    else
      Rails.application.config.application_name
    end
  end
end
