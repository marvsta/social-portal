Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get  "login",  to: "sessions#new",     as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  # Public signup is disabled: accounts are created by admins/owners from a
  # company's Users page, so every user is always assigned to a company.
  # (Bootstrap the very first admin from a console — see README.)

  # Global AI settings (provider + model used for every AI call, all companies)
  get   "ai_settings",      to: "ai_settings#show",   as: :ai_settings
  patch "ai_settings",      to: "ai_settings#update"
  post  "ai_settings/test", to: "ai_settings#test",   as: :test_ai_settings

  # Companies
  resources :companies, only: %i[index new create show edit update] do
    member do
      post :switch
    end
    resource :calendar, only: :show
    resource :dashboard, only: :show
    resources :memberships, path: "users", only: %i[index new create update destroy] do
      member do
        # Platform-admin-only: set a member's password (no self-service page yet).
        get   :edit_password
        patch :update_password
      end
    end
    resources :social_channels do
      collection do
        get :instagram_setup
      end
    end
    resources :posts do
      collection do
        post :generate_caption
        post :generate_image
      end
      member do
        post :submit_for_review
        post :approve
        post :schedule
        post :publish_now
      end
      resources :metrics, only: %i[index], controller: "post_metrics"
    end
  end

  root to: redirect("/companies")
end
