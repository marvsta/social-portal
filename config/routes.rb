Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get  "login",  to: "sessions#new",     as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  get  "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"

  # Companies
  resources :companies, only: %i[index new create show edit update] do
    member do
      post :switch
    end
    resource :calendar, only: :show
    resource :dashboard, only: :show
    resources :social_channels
    resources :posts do
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
