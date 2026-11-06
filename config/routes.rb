Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }
  devise_scope :user do
    post "users/guest_sign_in", to: "users/sessions#guest_sign_in"
  end

  # ログインの2段階目（認証アプリのコードを入れる画面）
  get "users/two_factor", to: "users/two_factor#new", as: :new_users_two_factor
  post "users/two_factor", to: "users/two_factor#create", as: :users_two_factor

  # 二段階認証の設定（有効にする・やめる）
  resource :two_factor_setting, only: %i[show new create destroy]

  resources :accounts do
    post :recheck, on: :member
  end
  resources :api_tokens, only: %i[index create destroy]

  namespace :api do
    namespace :v1 do
      resources :accounts, only: %i[index create]
    end
  end

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
