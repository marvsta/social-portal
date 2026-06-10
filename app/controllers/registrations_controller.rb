class RegistrationsController < ApplicationController
  layout "auth"
  allow_unauthenticated :new, :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      sign_in(@user)
      redirect_to new_company_path, notice: "Your account is ready. Let's set up your first company."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name)
  end
end
