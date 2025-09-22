Rails.application.routes.draw do
  # API routes for rule engine demonstration
  namespace :api do
    namespace :v1 do
      # User management
      resources :users, only: [:index, :show, :create, :update] do
        member do
          get :violations
          get :penalties
          post :suspend
          post :unsuspend
        end
      end
      
      # Violation reporting and processing
      resources :violations, only: [:index, :show, :create] do
        member do
          post :process
          post :reprocess
        end
      end
      
      # Rule management
      resources :rule_sets, only: [:index, :show, :create, :update] do
        member do
          post :enable
          post :disable
        end
        
        resources :rules, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :enable
            post :disable
          end
        end
      end
      
      # Analytics and reporting
      get 'analytics/violations', to: 'analytics#violations'
      get 'analytics/penalties', to: 'analytics#penalties'
      get 'analytics/rule_performance', to: 'analytics#rule_performance'
      
      # System health
      get 'health', to: 'health#check'
    end
  end
  
  # Root route
  root 'api/v1/health#check'
end
