# frozen_string_literal: true

Rails.application.routes.draw do
  # Chat UI (main interface)
  root 'chat#index'
  get 'chat', to: 'chat#index'
  get 'chat/stream', to: 'chat#stream'
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

      # Documents (read-only in this demo)
      resources :documents, only: %i[index show]

      # Categories and Brands
      resources :categories, only: %i[index show]
      resources :brands, only: %i[index show]

      # Stats
      get 'stats', to: 'stats#index'
    end
  end
end
