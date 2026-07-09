module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_session, :current_company, :current_membership, :signed_in?,
                  :can_manage_company?, :can_publish_company?, :accessible_companies
    before_action :require_login
  end

  class_methods do
    def allow_unauthenticated(*actions)
      skip_before_action :require_login, only: actions, raise: false
    end
  end

  private

  def current_session
    @current_session ||= find_session_from_cookie
  end

  def current_user
    @current_user ||= current_session&.user
  end

  def signed_in?
    current_user.present?
  end

  def current_company
    return @current_company if defined?(@current_company)
    @current_company = if current_user.nil?
      nil
    elsif params[:company_id].present?
      accessible_companies.find_by(slug: params[:company_id])
    elsif params[:controller] == "companies" && params[:id].present?
      accessible_companies.find_by(slug: params[:id])
    else
      current_user.current_company || accessible_companies.first
    end
  end

  # Admins can act on every company, not just the ones they're members of.
  def accessible_companies
    current_user.admin? ? Company.all : current_user.companies
  end

  def current_membership
    return @current_membership if defined?(@current_membership)
    company = current_company
    @current_membership = company && current_user&.memberships&.find_by(company_id: company.id)
  end

  def require_login
    return if signed_in?
    session[:return_to] = request.fullpath if request.get?
    redirect_to login_path, alert: "Please sign in to continue."
  end

  # Authorization gates. Platform admins (users.admin) pass every gate;
  # otherwise access is keyed off the current membership's role.
  # Manager == company owner; publisher == owner/editor.
  def require_manager
    deny_access unless can_manage_company?
  end

  def require_publisher
    deny_access unless can_publish_company?
  end

  def require_site_admin
    deny_access unless current_user&.admin?
  end

  def can_manage_company?
    current_user&.admin? || current_membership&.can_manage? || false
  end

  def can_publish_company?
    current_user&.admin? || current_membership&.can_publish? || false
  end

  def deny_access
    redirect_back fallback_location: companies_path,
      alert: "You don't have permission to do that."
  end

  def sign_in(user)
    new_session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
    cookies.encrypted.permanent[:session_token] = { value: new_session.token, httponly: true, same_site: :lax }
    @current_session = new_session
    @current_user = user
  end

  def sign_out
    current_session&.destroy
    cookies.delete(:session_token)
    @current_session = nil
    @current_user = nil
  end

  def find_session_from_cookie
    token = cookies.encrypted[:session_token]
    return nil if token.blank?
    Session.find_by(token: token)
  end

  def post_login_path
    session.delete(:return_to) || companies_path
  end
end
