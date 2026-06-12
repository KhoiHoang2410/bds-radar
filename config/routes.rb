require "sidekiq/web"
require "sidekiq/cron/web"

# In production, guard the dashboard with HTTP Basic auth (env-provided).
# Without both vars set the dashboard is closed, not open.
if Rails.env.production?
  Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
    expected_user = ENV["SIDEKIQ_WEB_USER"].to_s
    expected_password = ENV["SIDEKIQ_WEB_PASSWORD"].to_s
    next false if expected_user.empty? || expected_password.empty?

    ActiveSupport::SecurityUtils.secure_compare(user, expected_user) &
      ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
  end
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq dashboard (queues, retries, scheduled, + sidekiq-cron's Cron tab).
  mount Sidekiq::Web => "/sidekiq"

  resources :provinces, only: [ :index, :update ] do
    # PDF analytics export for the province's real-estate listings.
    # /report      → Prawn table report; /report/charts → matplotlib chart report.
    resource :report, only: [ :show ], controller: :reports do
      get :charts
    end
  end
  resources :real_estate_sources, only: [ :index ]
  resources :real_estates, only: [ :index, :show ]
end
