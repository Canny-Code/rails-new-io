# app/controllers/repositories_controller.rb
class RepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def index
    @repositories = @user.repositories
  end

  def new
    @repository = @user.repositories.build
  end

  def create
    begin
      GithubRepositoryService.new(@user)
        .create_repository(repository_params[:name])

      redirect_to user_repositories_path(@user), notice: "Repository created successfully!"
    rescue GithubRepositoryService::Error => e
      redirect_to new_user_repository_path(@user), alert: e.message
    end
  end

  private

  def set_user
    @user = User.friendly.find(params[:user_id])
  end

  def repository_params
    params.require(:repository).permit(:name)
  end

  def authenticate_user!
    unless current_user
      redirect_to root_path, alert: "Please sign in with GitHub first!"
    end
  end
end
