class CustomersController < ApplicationController
  before_action :authorized
  helper_method :current_user
  helper_method :logged_in?

  def create
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = addCustomerSchema()

    begin
      JSON::Validator.validate!(schema, json)
    rescue JSON::Schema::ValidationError => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    account = current_user

    existingCustomer = Customer.where('account_id = ? and email = ?', account['id'], json['email']).first
    if(!existingCustomer.nil?)
      output = {'message' => 'Customer already exists on this account'}.to_json
      render json: output, :status => :bad_request and return
    end

    user = Customer.create(
      first_name: json['first_name'],
      last_name: json['last_name'],
      company_name: json['company_name'],
      email: json['email'],
      phone: json['phone'],
      currency: "GBP",
      account_id: account['id']
    );

    Address.create(
      address_line: json['address_line'],
      city: json['city'],
      postal_code: json['postal_code'],
      customer_id: user['id']
    );

    output = {'message' => 'Success'}.to_json
    render json: output
  end

  def addCustomerSchema
    return {
      "type" => "object",
      "required" => %w[first_name last_name company_name email phone address_line city postal_code],
      "properties" => {
        "first_name" => {"type" => "string"},
        "last_name" => {"type" => "string"},
        "company_name" => {"type" => "string"},
        "email" => {"type" => "string"},
        "phone" => {"type" => "string"},
        "address_line" => {"type" => "string"},
        "city" => {"type" => "string"},
        "postal_code" => {"type" => "string"}
      }
    }
  end

  def get
    account = current_user
    customers = Customer.where('account_id = ?', account['id'])
    if(customers.nil?)
      output = {'message' => 'No customers on this Account'}.to_json
      render json: output, :status => :accepted and return
    end

    render json: customers, status: :ok
  end
end
