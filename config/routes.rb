Rails.application.routes.draw do

  root "static_pages#root"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  namespace :api, defaults: { format: :json } do
    resources :tweets, only: [:index, :show]
    resources :streams, only: [:index]
    resources :trends, only: [:index]
  end
end
