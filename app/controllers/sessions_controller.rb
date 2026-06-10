class SessionsController < ApplicationController
  layout "auth"
  allow_unauthenticated :new, :create

  def new
    redirect_to companies_path if signed_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)
    if user&.authenticate(params[:password])
      sign_in(user)
      redirect_to post_login_path, notice: "Welcome back, #{user.display_name}."
    else
      flash.now[:alert] = "Email or password is incorrect."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    sign_out
    redirect_to login_path, notice: "Signed out."
  end
end
