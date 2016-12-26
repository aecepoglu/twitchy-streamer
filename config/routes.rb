Rails.application.routes.draw do
  get 'welcome/index'
  get 'about' => 'pages#about'

  scope '/api' do
    get '/version', to: 'version#list'#, controller: 'version'
    
    
    scope '/0.1' do
      get '/check', to: 'health_check#show'
    end
  end

  resources :projects do
    resources :assets

    member do
      post "sync"
    end
  end

  root "welcome#index"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
