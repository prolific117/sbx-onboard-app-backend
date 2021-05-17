class UsersController < ApplicationController
  def signup
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = signupSchema()

    begin
      JSON::Validator.validate!(schema, json)
    rescue JSON::Schema::ValidationError => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    existingUser = User.find_by(email: json['email'])
    if(!existingUser.nil?)
      output = {'message' => 'Email already exists'}.to_json
      render json: output, :status => :bad_request and return
    end

    user = User.create(
      first_name: json['first_name'],
      last_name: json['last_name'],
      company_name: json['company_name'],
      email: json['email'],
      password: json['password'],
      is_verified: false
    );

    sessionId = rand(36**16).to_s(36)
    session[sessionId] = user.id

    output = {'session_id' => sessionId}.to_json
    render json: output
  end

  def signupSchema
    return {
      "type" => "object",
      "required" => %w[first_name last_name company_name email password],
      "properties" => {
        "first_name" => {"type" => "string"},
        "last_name" => {"type" => "string"},
        "company_name" => {"type" => "string"},
        "email" => {"type" => "string"},
        "password" => {"type" => "string"}
      }
    }
  end

  def login
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = loginSchema()

    begin
      JSON::Validator.validate!(schema, json)
    rescue JSON::Schema::ValidationError => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    user = User.find_by(email: json['email'])

    if user && user.authenticate(json['password'])
      sessionId = rand(36**32).to_s(36)
      session[sessionId] = user.id

      output = {'session_id' => sessionId}.to_json
      render json: output
    else
      output = {'message' => 'Incorrect Password'}.to_json
      render json: output, :status => :bad_request
    end
  end

  def loginSchema
    return {
      "type" => "object",
      "required" => %w[email password],
      "properties" => {
        "email" => {"type" => "string"},
        "password" => {"type" => "string"}
      }
    }
  end
end

