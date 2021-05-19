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


  def singlePaymentSchema
    return {
      "type" => "object",
      "required" => %w[amount],
      "properties" => {
        "amount" => {"type" => "integer"}
      }
    }
  end

  def collectOneOffPayment
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = singlePaymentSchema()

    begin
      JSON::Validator.validate!(schema, json)
    rescue JSON::Schema::ValidationError => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    account = current_user

    if(!canPerformGCOperations(account))
      output = {'message' => 'Account cannot add users, please authorize with Gocardless and Complete Verification'}.to_json
      render json: output, :status => :bad_request and return
    end

    customer = Customer.find_by(id: params['customer_id'])
    if(customer.nil?)
      output = {'message' => 'Customer does not exist'}.to_json
      render json: output, :status => :not_found and return
    end

    if(customer['account_id'] != account['id'])
      output = {'message' => 'You are not allowed to perform this operation'}.to_json
      render json: output, :status => :unauthorized and return
    end

    mandate = Mandate.where('customer_id = ?', customer['id']).first
    client = GoCardlessPro::Client.new(
      access_token: current_user.gocardless_access_token,
      environment: :sandbox
    )

    payment = client.payments.create(
      params: {
        amount: json['amount'], # 10 GBP in pence, collected from the end customer.
        app_fee: 10, # 10 pence, to be paid out to you.
        currency: 'GBP',
        links: {
          mandate: mandate.mandate
          # The mandate ID from last section
        },
        # Almost all resources in the API let you store custom metadata,
        # which you can retrieve later
        metadata: {
          invoice_number: rand.to_s[2..10]
        }
      },
      headers: {
        'Idempotency-Key' => 'random_payment_specific_string'
      }
    )

    puts "ID: #{payment.id}"
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
