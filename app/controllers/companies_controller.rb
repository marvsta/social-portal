class CompaniesController < ApplicationController
  before_action :load_company, only: %i[show edit update switch]
  before_action :require_membership, only: %i[show edit update switch]
  before_action :require_manager, only: %i[edit update]

  def index
    @companies = current_user.companies.order(:name)
    redirect_to new_company_path and return if @companies.empty?
  end

  def new
    @company = Company.new(timezone: Time.zone.name)
  end

  def create
    @company = Company.new(company_params)
    Company.transaction do
      @company.save!
      Membership.create!(user: current_user, company: @company, role: "owner")
      current_user.update!(current_company: @company)
    end
    redirect_to company_calendar_path(@company), notice: "Welcome to #{@company.name}!"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def show
    redirect_to company_calendar_path(@company)
  end

  def edit
  end

  def update
    if @company.update(company_params)
      redirect_to edit_company_path(@company), notice: "Company updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def switch
    current_user.update(current_company: @company)
    redirect_to company_calendar_path(@company)
  end

  private

  def load_company
    @company = Company.find_by!(slug: params[:id])
  end

  def require_membership
    return if current_user.member_of?(@company)
    redirect_to companies_path, alert: "You don't have access to that company."
  end

  def company_params
    params.require(:company).permit(:name, :slug, :logo_url, :website, :timezone, :description)
  end
end
