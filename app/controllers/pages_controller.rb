class PagesController < ApplicationController
  before_action :authenticate_user!

  def new
    @page = Page.includes(
      groups: {
        sub_groups: {
          elements: [ :variant, :user ]
        }
      }
    ).joins(groups: { sub_groups: { elements: :user } })
     .where("elements.user_id = ? OR users.github_username = ?", Current.user.id, "rails-new-io")
     .friendly.find(params[:slug])
  end

  def edit
    @page = Page.includes(
      groups: {
        sub_groups: {
          elements: [ :variant, :user ]
        }
      }
    ).joins(groups: { sub_groups: { elements: :user } })
     .where("elements.user_id = ? OR users.github_username = ?", Current.user.id, "rails-new-io")
     .friendly.find(params[:slug])

    @recipe = Recipe.find(params[:recipe_id])
  end
end
