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

  def recurringPaymentSchema
    return {
      "type" => "object",
      "required" => %w[amount frequency day_of_month],
      "properties" => {
        "amount" => {"type" => "integer"},
        "frequency" => {"type" => "string"},
        "day_of_month" => {"type" => "integer"}
      }
    }
  end

  def checkPermission(account, customer)
    if(!canPerformGCOperations(account))
      output = {'message' => 'Account cannot add users, please authorize with Gocardless and Complete Verification'}
      return {canProceed: false, status: :bad_request, reason: output}
    end

    if(customer.nil?)
      output = {'message' => 'Customer does not exist'}
      return {canProceed: false, status: :bad_request, reason: output}
    end

    if(customer['account_id'] != account['id'])
      output = {'message' => 'You are not allowed to perform this operation'}
      return {canProceed: false, status: :unauthorized, reason: output}
    end

    return {canProceed: true}

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
    customer = Customer.find_by(id: params['customer_id'])

    permission = checkPermission(account, customer)
    if(!permission['canProceed'])
      render json: permission[:reason], :status => permission[:status] and return
    end

    if(json['amount'] < 200)
      output = {'message' => 'Minimum amount is 200 pence'}.to_json
      render json: output, :status => :bad_request and return
    end

    mandate = Mandate.where('customer_id = ?', customer['id']).first
    if(mandate.nil?)
      output = {'message' => 'No mandates exist for customer'}.to_json
      render json: output, :status => :not_found and return
    end

    client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    invoice_number = rand.to_s[2..10]
    begin
      payment = client.payments.create(
        params: {
          amount: json['amount'], # 10 GBP in pence, collected from the end customer.
          app_fee: 10, # 10 pence, to be paid out to you.
          currency: 'GBP',
          links: {
            mandate: mandate.mandate
          },
          metadata: {
            invoice_number: invoice_number
          }
        },
        headers: {
          'Idempotency-Key' => rand(36**32).to_s(36)
        }
      )
    rescue => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    Payment.create(
      mandate_id: mandate['id'],
      status: 'pending_submission',
      amount: json['amount'],
      customer_id: customer['id'],
      invoice_number: invoice_number,
      payment_id: payment.id,
      payment_type: 'one-off'
    );

    output = {'payment_id' => payment.id}.to_json
    render json: output
  end

  def getCustomerPayments
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

    @client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    begin
      records = @client.payments.list(params: { customer: customer['gocardless_customer_id']  }).records
    rescue => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    payments = []
    records.each do |record|
      payments.push({
                      'amount' => record.amount,
                      'created_at' => record.created_at,
                      'amount_refunded' => record.amount_refunded,
                      'charge_date' => record.charge_date,
                      'currency' => record.currency,
                      'invoice_number' => record.metadata['invoice_number']
                    }
      )
    end

    render json: payments and return
  end

  def getCustomerSubscriptions
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

    @client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    begin
      records = @client.subscriptions.list(params: { customer: customer['gocardless_customer_id']  }).records
    rescue => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    subscriptions = []
    records.each do |record|
      subscriptions.push({
                      'amount' => record.amount,
                      'created_at' => record.created_at,
                      'start_date' => record.start_date,
                      'end_date' => record.end_date,
                      'currency' => record.currency,
                      'invoice_number' => record.metadata['invoice_number'],
                      'upcoming_payments' => record.upcoming_payments
                    }
      )
    end

    render json: subscriptions and return
  end

  def collectRecurringPayment
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = recurringPaymentSchema()

    begin
      JSON::Validator.validate!(schema, json)
    rescue JSON::Schema::ValidationError => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    account = current_user

    if(json['amount'] < 200)
      output = {'message' => 'Minimum amount is 200 pence'}.to_json
      render json: output, :status => :bad_request and return
    end

    customer = Customer.find_by(id: params['customer_id'])
    permission = checkPermission(account, customer)
    if(!permission[:canProceed])
      render json: permission[:reason], :status => permission[:status] and return
    end

    mandate = Mandate.where('customer_id = ?', customer['id']).first
    if(mandate.nil?)
      output = {'message' => 'No mandates exist for customer'}.to_json
      render json: output, :status => :not_found and return
    end

    client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    invoice_number = rand.to_s[2..10]
    begin
      subscription = client.subscriptions.create(
        params: {
          amount: json['amount'], # 15 GBP in pence, collected from the customer
          app_fee: 10, # 10 pence, to be paid out to you
          currency: 'GBP',
          interval_unit: json['frequency'],
          day_of_month: json['day_of_month'],
          links: {
            mandate: mandate.mandate
            # Mandate ID from the last section
          },
          metadata: {
            subscription_number: invoice_number
          }
        },
        headers: {
          'Idempotency-Key' => rand(36**32).to_s(36)
        }
      )
    rescue => e
      render json: {'message' => e.message}.to_json, :status => :bad_request and return
    end

    Payment.create(
      mandate_id: mandate['id'],
      status: 'pending_submission',
      amount: json['amount'],
      interval: json['interval'],
      day_of_month:json['day_of_month'],
      customer_id: customer['id'],
      invoice_number: invoice_number,
      subscription_id: subscription.id,
      payment_type: 'recurring'
    );

    output = {'subscription_id' => subscription.id}.to_json
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

  def getCustomer
    account = current_user
    customer = Customer.find_by(id: params['customer_id'])
    if(customer.nil? || account.id != customer.account_id)
      output = {'message' => 'Customer does not exist'}.to_json
      render json: output, :status => :accepted and return
    end

    render json: customer, status: :ok
  end
end
