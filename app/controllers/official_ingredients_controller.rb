class OfficialIngredientsController < ApplicationController
  before_action :authenticate_user!

  def index
    @ingredients = Ingredient.where(created_by: User.find_by(github_username: "rails-new-io"))
    render "ingredients/index"
  end
end
