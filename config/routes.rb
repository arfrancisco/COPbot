Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Health check endpoint for Heroku
  get '/health', to: proc { [200, {}, ['OK']] }

  # Sidekiq web UI (mount with authentication in production)
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
