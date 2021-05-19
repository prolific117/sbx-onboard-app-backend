module Blog
  class Application < Rails::Application
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', :headers => 'Authorization', :methods => [:get, :post, :delete, :patch, :options]
      end
    end
  end
end