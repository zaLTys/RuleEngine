require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module RailsApiDemo
  class Application < Rails::Application
    config.load_defaults 7.0
    
    # Configuration for the application, engines, and railties goes here.
    config.api_only = true
    
    # Enable CORS for API access
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end
  end
end
