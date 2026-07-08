class MembershipsController < ApplicationController
  include CompanyScoped

  before_action :require_manager, only: %i[new create update destroy]
  before_action :load_membership, only: %i[update destroy]

  def index
    @memberships = @company.memberships.includes(:user).joins(:user).order("users.name, users.email")
  end

  def new
    @membership = @company.memberships.build(role: "editor")
  end

  def create
    email = params.dig(:membership, :email).to_s.strip.downcase
    role = params.dig(:membership, :role)

    if email.blank?
      return redirect_to new_company_membership_path(@company), alert: "Enter an email address."
    end

    user = User.find_by(email: email)
    temp_password = nil

    if user.nil?
      # No mailer is wired up yet, so we create the account here and show the
      # temporary password once for the manager to pass on securely.
      temp_password = SecureRandom.alphanumeric(12)
      user = User.new(
        email: email,
        name: params.dig(:membership, :name).to_s.strip,
        password: temp_password,
        password_confirmation: temp_password
      )
      unless user.save
        @membership = @company.memberships.build(role: role)
        flash.now[:alert] = user.errors.full_messages.to_sentence
        return render :new, status: :unprocessable_content
      end
    elsif user.member_of?(@company)
      return redirect_to company_memberships_path(@company), alert: "#{user.display_name} is already a member."
    end

    @membership = @company.memberships.build(user: user, role: role)
    if @membership.save
      notice = "#{user.display_name} added as #{@membership.role}."
      notice += " Temporary password: #{temp_password} — share it securely; they should change it after signing in." if temp_password
      redirect_to company_memberships_path(@company), notice: notice
    else
      user.destroy if temp_password # don't leave an orphaned account we just created
      flash.now[:alert] = @membership.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    new_role = params.dig(:membership, :role)
    if demoting_last_owner?(@membership, new_role)
      return redirect_to company_memberships_path(@company), alert: "There must be at least one owner."
    end
    if @membership.update(role: new_role)
      redirect_to company_memberships_path(@company), notice: "#{@membership.user.display_name} is now #{@membership.role}."
    else
      redirect_to company_memberships_path(@company), alert: @membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @membership.user_id == current_user.id
      return redirect_to company_memberships_path(@company), alert: "You can't remove yourself."
    end
    if @membership.role == "owner" && owner_count == 1
      return redirect_to company_memberships_path(@company), alert: "There must be at least one owner."
    end
    @membership.destroy
    redirect_to company_memberships_path(@company), notice: "#{@membership.user.display_name} removed from #{@company.name}."
  end

  private

  def load_membership
    @membership = @company.memberships.find(params[:id])
  end

  def owner_count
    @company.memberships.where(role: "owner").count
  end

  def demoting_last_owner?(membership, new_role)
    membership.role == "owner" && new_role != "owner" && owner_count == 1
  end
end
