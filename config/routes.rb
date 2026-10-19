Rails.application.routes.draw do
  # Dashboard view
  root "users#index"

  # User management bulk actions
  resources :users, only: [:index] do
    collection do
      patch :block
      patch :unblock
      delete :destroy_multiple
    end
  end

  # AI Chat endpoint (Mandatory for Part 2)
  post "ai_chat", to: "ai_chats#create"

  # Registration routes
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"

  # Authentication routes
  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"
end