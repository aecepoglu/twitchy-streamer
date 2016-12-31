Rails.application.routes.draw do
  get 'about' => 'welcome#about'
  root 'welcome#index'

  scope '/api' do
    get '/version', to: 'version#list'#, controller: 'version'
    
    
    scope '/0.1' do
      get '/check', to: 'health_check#show'
    end
  end

  resources :projects do
    member do
      post "sync"
      get "dir"
    end
  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
