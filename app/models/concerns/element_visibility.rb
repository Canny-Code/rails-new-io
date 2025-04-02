# frozen_string_literal: true

module ElementVisibility
  extend ActiveSupport::Concern

  class_methods do
    def visible_for_user?(element, user, page_title)
      # Current user's elements are always visible
      return true if element.user_id == user.id

      # For "Your Custom Ingredients" page, only show current user's elements
      return false if page_title == "Your Custom Ingredients"

      # For other pages, also show rails-new-io's elements
      element.user.github_username == "rails-new-io"
    end
  end
end
