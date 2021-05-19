class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
  protect_from_forgery

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
