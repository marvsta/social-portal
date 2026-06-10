class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  layout :resolve_layout

  protect_from_forgery with: :exception

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def resolve_layout
    if respond_to?(:devise_controller?) && devise_controller?
      "auth"
    else
      "application"
    end
  end

  def record_not_found
    redirect_to root_path, alert: "We couldn't find what you were looking for."
  end
end
