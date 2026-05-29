# frozen_string_literal: true

Rails.application.routes.draw do
  root 'comments#index'

  get 'up' => 'rails/health#show', as: :rails_health_check

  devise_for :users, controllers: {
    registrations: 'users/registrations',
  }

  resources :comments, only: %i[index create edit update destroy] do
    collection do
      get :mine
    end
  end

  resources :notifications, only: [:index] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
    end
  end
end
