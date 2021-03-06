class ApplicationController < ActionController::Base
  protect_from_forgery

  helper_method :namespace, :current_user, :user_logged_in?

  before_action :set_current_user

  protected

  def namespace
     self.class.parent.to_s.downcase.to_sym
  end

  def current_user
    return @current_user unless @current_user.nil?

    username = session[:username] || session['cas'].try(:[], 'user')
    cas_attrs = session['cas'].try(:[], 'extra_attributes') || {}

    return nil if username.nil?

    @current_user = User.find_or_initialize_by_username(username).tap do |user|
      if !session[:username] # first time returning from CAS
        user.update_from_cas! cas_attrs unless Rails.env.test?
        user.update_login_info!
      end

      if user.new_record?
        user = nil
      else
        session[:username] = user.username
      end
    end
  end

  impersonates :user

  def set_current_user
    Authorization.current_user = current_user
  end

  def user_logged_in?
    current_user.present?
  end

  def permission_denied!
    render_error_page(user_logged_in? ? 403 : 401)
  end
  alias :permission_denied :permission_denied!

  def render_error_page(status)
    render file: "#{Rails.root}/public/#{status}", formats: [:html], status: status, layout: false
  end
end
