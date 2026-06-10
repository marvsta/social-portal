module CompanyScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_scoped_company
    before_action :require_company_membership
  end

  private

  def load_scoped_company
    slug = params[:company_id] || params[:id]
    @company = Company.find_by!(slug: slug)
  end

  def require_company_membership
    return if current_user&.member_of?(@company)
    redirect_to companies_path, alert: "You don't have access to that company."
  end

  def current_company
    @company
  end
end
