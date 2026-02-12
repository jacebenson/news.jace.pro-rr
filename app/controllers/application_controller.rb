class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return true if logged_in?
    flash[:alert] = "Please log in to access this page"
    redirect_to login_path
    false
  end

  def require_admin
    return false unless require_login
    return true if current_user&.admin?
    flash[:alert] = "You don't have permission to access this page"
    redirect_to items_path
    false
  end

  # Sanitize user input for SQL LIKE queries to prevent wildcard injection
  # Escapes % and _ characters that have special meaning in LIKE patterns
  def sanitize_sql_like(string)
    string.to_s.gsub(/[%_\\]/) { |x| "\\#{x}" }
  end
end
