class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def current_user
    @authorization = request.headers["Authorization"]
    User.find_by(id: session[@authorization])
  end

  def logged_in?
    !current_user.nil?
  end

  def isAuthorized(account)
    if(account['access_token'].nil?)
      return false
    end

    return true
  end

  def isVerified(account)
    if(account['is_verified'].nil? or account['is_verified'] == false)
      return false
    end

    return true
  end

  def canPerformGCOperations(account)
    if(!isAuthorized(account) or !isVerified(account))
      return false
    end

    return true
  end

  def authorized
    output = {'message' => 'Unauthorized', 'header' => request.headers["Authorization"]}.to_json
    render json: output, :status => :unauthorized unless logged_in?
  end
end
