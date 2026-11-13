Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "conversations#index"

  resources :conversations, only: %i[index show create] do
    resources :messages, only: :create
  end

  resources :feedback_notes, only: %i[index show new create]

  resources :insights, only: %i[index show] do
    scope module: :insights do
      resource :link, only: :create
      resource :dismissal, only: :create
      resource :feature, only: :create
    end
  end

  resources :products, only: %i[index new create edit update]
  resources :features, only: %i[index show new create edit update]
  resources :customers, only: %i[index show]
  resources :knowledge_documents, except: :show

  resources :integrations, only: %i[index show update] do
    scope module: :integrations do
      resource :sync, only: :create
      resources :simulated_messages, only: :create
    end
  end

  # Slack Events API (signed by Slack, no session)
  namespace :slack do
    resources :events, only: :create
  end

  # The fake LiteLLM (lib/mock_llm.rb) when no LITELLM_URL is set
  mount MockLlm.new => "/mock_llm" if Rails.env.development? && Rails.configuration.x.mock_llm

  get "up" => "rails/health#show", as: :rails_health_check
end
