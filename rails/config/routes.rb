Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'health_check', to: 'health_check#index'
      mount_devise_token_auth_for 'User', at: 'auth'

      namespace :current do
        resource :user, only: [:show]
        resources :articles, only: %i[index show create update]
      end

      resources :articles, only: %i[index show]
    end
  end

  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
