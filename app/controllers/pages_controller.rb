class PagesController < ApplicationController
  before_action :authenticate_user!
  def show
    @page = Page.includes(
      groups: {
        sub_groups: {
          elements: [ :variant ]
        }
      }
    ).friendly.find(params[:slug])
  end
end
