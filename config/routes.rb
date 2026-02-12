Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root redirects to news items
  root "news_items#index"

  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "signup", to: "users#new"
  post "signup", to: "users#create"
  get "forgot-password", to: "passwords#new"
  post "forgot-password", to: "passwords#create"
  get "reset-password", to: "passwords#edit"
  patch "reset-password", to: "passwords#update"

  # Public pages
  # News Items (/i)
  get "i", to: "news_items#index", as: :items
  get "i/participant/:participant", to: "news_items#index", as: :items_by_participant
  get "i/search/:search", to: "news_items#index", as: :items_search
  get "i/:id", to: "news_items#show", as: :item, constraints: { id: /\d+/ }
  get "r/search/:search", to: "news_items#index", as: :items_search_alt

  # Partners (/p)
  get "p", to: "partners#index", as: :partners
  get "p/search/:search", to: "partners#index", as: :partners_search
  get "p/:id", to: "partners#show", as: :partner, constraints: { id: /\d+/ }

  # Customers - admin only (removed public routes)

  # Store Apps (/a)
  get "a", to: "applications#index", as: :applications
  get "a/search/:search", to: "applications#index", as: :applications_search
  get "a/company/:company", to: "applications#index", as: :applications_by_company
  get "a/:id", to: "applications#show", as: :application, constraints: { id: /\d+/ }

  # Participant profile
  get "who/:name", to: "participants#show", as: :who
  post "participants/:id/link-company", to: "participants#link_company", as: :participant_link_company

  # API endpoints
  namespace :api do
    get "companies/search", to: "companies#search"
  end

  # Knowledge Sessions - all events
  %w[k20 k21 k22 k23 k24 k25 k26 nulledge25].each do |event|
    get "#{event}", to: "knowledge_sessions#index", defaults: { event: event }, as: event.to_sym
    get "#{event}/list/:list", to: "knowledge_sessions#index", defaults: { event: event }, as: "#{event}_list".to_sym
    get "#{event}/search/:search", to: "knowledge_sessions#index", defaults: { event: event }, as: "#{event}_search".to_sym
    get "#{event}/tags/:tags", to: "knowledge_sessions#index", defaults: { event: event }, as: "#{event}_tags".to_sym
    get "#{event}/tags/:tags/:filter", to: "knowledge_sessions#index", defaults: { event: event }, as: "#{event}_tags_filter".to_sym
    get "#{event}/tags/:tags/search/:search", to: "knowledge_sessions#index", defaults: { event: event }, as: "#{event}_tags_search".to_sym
  end

  # Account (authenticated)
  get "account", to: "accounts#show"
  patch "account", to: "accounts#update"

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    post "dashboard/trigger-s3-migration", to: "dashboard#trigger_s3_migration", as: :trigger_s3_migration
    resources :users
    resources :companies
    resources :participants do
      member do
        post :link_company
      end
    end
    resources :news_feeds
    resources :news_items
    resources :knowledge_sessions
    resources :store_apps, controller: "servicenow_store_apps"
    resources :investments, controller: "servicenow_investments"
    get "background-jobs", to: "background_jobs#index", as: :background_jobs
    post "background-jobs/run", to: "background_jobs#run_job", as: :run_job
    post "background-jobs/cancel", to: "background_jobs#cancel_job", as: :cancel_job
    post "background-jobs/retry-failed", to: "background_jobs#retry_failed", as: :retry_failed
    post "background-jobs/clear-failed", to: "background_jobs#clear_failed", as: :clear_failed
  end

  # Catch-all slug route (must be last)
  get ":slug", to: "slugs#show", as: :slug
end
