class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
  protect_from_forgery
  before_filter :cors_preflight_check
  after_filter :cors_set_access_control_headers

  # For all responses in this controller, return the CORS access control headers.

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS, PATCH'
    headers['Access-Control-Allow-Headers'] = %w{Origin Accept Content-Type X-Requested-With auth_token X-CSRF-Token}.join(',')
    headers['Access-Control-Max-Age'] = "1728000"
  end

  def cors_preflight_check
    if request.method == "OPTIONS"
      headers['Access-Control-Allow-Origin'] = 'http://localhost'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS, PATCH'
      headers['Access-Control-Allow-Headers'] = %w{Origin Accept Content-Type X-Requested-With auth_token X-CSRF-Token}.join(',')
      headers['Access-Control-Max-Age'] = '1728000'
      render :text => '', :content_type => 'text/plain'
    end
  end

  def current_user
    @authorization = request.headers["Authorization"]
    User.find_by(id: session[@authorization])
  end

  def logged_in?
    !current_user.nil?
  end

  def authorized
    output = {'message' => 'Unauthorized'}.to_json
    render json: output, :status => :unauthorized unless logged_in?
  end
end
