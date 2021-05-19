class GocardlessController < ApplicationController
  before_action :authorized
  helper_method :current_user
  helper_method :logged_in?

  def gcSignup
    authorize('read_write')
  end

  def gcLogin
    authorize('read_only')
  end

  def authorize(mode)
    account = current_user
    if(isAuthorized(account))
      output = {'message' => 'Account is already authorized'}.to_json
      render json: output, :status => :created and return
    end

    oauth = getClient()

    authorize_url = oauth.auth_code.authorize_url(
      redirect_uri: ENV['REDIRECT_URL'],
      scope: mode,
      prefill: {
        email: account['email'],
        given_name: account['first_name'],
        family_name: account['last_name'],
        organisation_name: account['company_name']
      })

    output = {'redirect_url' => authorize_url}.to_json
    render json: output, :status => :accepted
  end

  def getClient()
    return OAuth2::Client.new(
      ENV['GOCARDLESS_CLIENT_ID'],
      ENV['GOCARDLESS_CLIENT_SECRET'],
      site: ENV['GOCARDLESS_CONNECT_URL'],
      authorize_url: '/oauth/authorize',
      token_url: '/oauth/access_token'
    )
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

  def connect()
    output = {'organisation_id' => access_token['organisation_id']}.to_json
    render json: output and return
    account = current_user

    oauth = getClient()

    access_token = oauth.auth_code.get_token(
      params[:code],
      redirect_uri: ENV['REDIRECT_URL']
    )

    account.update!(access_token: access_token.token,
                    organisation_id: access_token['organisation_id'],
                    is_verified: false)

    #Send email to verify here
    VerifyMailer.with(user: account, url: 'https://verify-sandbox.gocardless.com').verify_email.deliver_now

    output = {'organisation_id' => access_token['organisation_id']}.to_json
    render json: output
  end

  def getCurrentVerificationStatus()
    account = current_user

    client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    creditor = client.creditors.list.records.first

    if creditor.verification_status == "successful"
      account.update!(is_verified: true)
      return true
    end

    return false
  end

  def getMandatesForCustomer
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

    records = @client.mandates.list(params: { customer: "CU000FRXY66HG3" }).records

    mandates = []
    records.each do |record|
      mandates.push({
                      'mandate_id' => record.id,
                      'created_at' => record.created_at,
                      'scheme' => record.scheme,
                      'status' => record.status,
                      'reference' => record.reference
                    }
      )
    end

    render json: mandates and return
  end

  def addCustomerToGocardless()
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = mandateSetupSchema()

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

    customer = Customer.find_by(id: json['customer_id'])
    if(customer.nil?)
      output = {'message' => 'Customer does not exist'}.to_json
      render json: output, :status => :not_found and return
    end

    if(customer['account_id'] != account['id'])
      output = {'message' => 'You are not allowed to perform this operation'}.to_json
      render json: output, :status => :unauthorized and return
    end

    address = Address.where('customer_id = ?', customer['id']).first
    client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    sessionId = "cust-#{rand(36**32).to_s(36)}"
    session["mandate-session-#{customer['id']}"] = sessionId

    redirect_flow = client.redirect_flows.create(
      params: {
        description: "Automatic invoice payments to #{customer['company_name']}",
        session_token: sessionId,
        success_redirect_url: "http://localhost:5000/mandate?user_id=#{customer['id']}",
        prefilled_customer: {
          given_name: customer.first_name,
          family_name: customer.last_name,
          email: customer.email,
          address_line1: address['address_line'],
          city: address['city'],
          postal_code: address['postal_code']
        }
      }
    )

    output = {'redirect_url' => redirect_flow.redirect_url, "session_token" => sessionId}.to_json
    render json: output
  end

  def mandateSetupSchema
    return {
      "type" => "object",
      "required" => %w[customer_id],
      "properties" => {
        "customer_id" => {"type" => "integer"},
      }
    }
  end

  def mandateCompleteSchema
    return {
      "type" => "object",
      "required" => %w[customer_id redirect_flow_id],
      "properties" => {
        "customer_id" => {"type" => "integer"},
        "redirect_flow_id" => {"type" => "string"}
      }
    }
  end

  def completeGocardlessMandate()
    respond_to :json
    json = JSON.parse(request.body.read)
    schema = mandateCompleteSchema()

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

    client = GoCardlessPro::Client.new(
      access_token: account['access_token'],
      environment: :sandbox
    )

    customer = Customer.find_by(id: json['customer_id'])
    if(customer.nil?)
      output = {'message' => 'Customer does not exist'}.to_json
      render json: output, :status => :not_found and return
    end

    if(customer['account_id'] != account['id'])
      output = {'message' => 'You are not allowed to perform this operation'}.to_json
      render json: output, :status => :unauthorized and return
    end

    sessionId = session["mandate-session-#{json['customer_id']}"]

    if (sessionId.nil?)
      output = {'message' => 'Session token does not exist or expired'}.to_json
      render json: output, :status => :bad_request and return
    end

    redirect_flow = client.redirect_flows.complete(
      json['redirect_flow_id'], # The value of the `redirect_flow_id` query parameter
      params: { session_token: sessionId }) # The session token you specified earlier

    Mandate.create(
      customer_id: json['customer_id'],
      status: 'pending_submission',
      mandate: redirect_flow.links.mandate
    );

    customer.update!(gocardless_customer_id: redirect_flow.links.customer)

    output = {
      'confirmationUrl' => redirect_flow.confirmation_url,
      'mandate' => redirect_flow.links.mandate
    }.to_json
    render json: output
  end

  def getConnectionState()
    account = current_user
    if (account['access_token'].nil?)
      output = {
        'is_authorized' => account['access_token'].nil? ?  :false : :true,
        'is_verified' => account['is_verified']
      }

      render json: output.to_json and return
    end


    if (!account['access_token'].nil? && account['is_verified'].nil? or account['is_verified'] == false)
      #check with api
      output['is_verified'] = getCurrentVerificationStatus
    else
      output['is_verified'] = true
    end

    render json: output.to_json
  end
end
