module Admin
  class UsersController < ApplicationController
    layout "admin"
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @users = User.all
    end

    def show
    end
    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "User was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "User was successfully destroyed."
    end

    private

    def set_user
      @user = User.friendly.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :name, :onboarding_completed)
    end
  end
end
