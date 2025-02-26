class PagesController < ApplicationController
  before_action :authenticate_user!

  def new
    @page = Page.includes(
      groups: {
        sub_groups: {
          elements: [ :variant ]
        }
      }
    ).friendly.find(params[:slug])
  end

  def edit
    @page = Page.includes(
      groups: {
        sub_groups: {
          elements: [ :variant ]
        }
      }
    ).friendly.find(params[:slug])
    @recipe = Recipe.find(params[:recipe_id])
  end
end
