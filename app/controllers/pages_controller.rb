class PagesController < ApplicationController
  def show
    @page = Page.includes(
      groups: {
        sub_groups: {
          elements: [ :variant ]
        }
      }
    ).friendly.find(params[:id] || params[:slug])
  end
end
