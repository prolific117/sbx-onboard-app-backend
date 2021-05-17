Rails.application.routes.draw do
  post "/customer", to: "customers#create"
  get "/customers", to: "customers#get"
  post "/login", to: "users#login"
  match '/user' => 'users#signup', via: :post
  get 'authorized', to: 'sessions#page_requires_login'
  get "/gocardless/authorize/signup", to: "gocardless#gcSignup"
  get "/gocardless/authorize/login", to: "gocardless#gcLogin"
  get "/gocardless/connect/:code", to: "gocardless#connect"
  get "/gocardless/state", to: "gocardless#getConnectionState"
  get "/gocardless/state", to: "gocardless#getConnectionState"
  get "/gocardless/verify", to: "gocardless#verifyAccountAndUpdate"
  post "/gocardless/customer", to: "gocardless#addCustomerToGocardless"
  post "/gocardless/complete-mandate", to: "gocardless#completeGocardlessMandate"
  get "/gocardless/mandates/:customer_id", to: "gocardless#getMandatesForCustomer"
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
