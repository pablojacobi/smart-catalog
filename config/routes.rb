# frozen_string_literal: true

Rails.application.routes.draw do
  # Authentication (Devise)
  devise_for :users, skip: [:registrations]

  # Landing page (public)
  root 'home#index'

  # Chat UI (protected)
  get 'chat', to: 'chat#index', as: :chat
  get 'chat/stream', to: 'chat#stream', as: :chat_stream
  get 'chat/:id', to: 'chat#show', as: :chat_conversation

  # Health check
  get 'health', to: 'health#show'

  # API v1
  namespace :api do
    namespace :v1 do
      # Chat endpoint (main AI interface)
      post 'chat/completions', to: 'chat#completions'

      # Products
      resources :products, only: %i[index show]

      # Categories and Brands
      resources :categories, only: %i[index show]
      resources :brands, only: %i[index show]

      # Stats
      get 'stats', to: 'stats#index'
    end
  end
end
