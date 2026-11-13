Rails.application.routes.draw do
  resource :session
  resource :signup, only: %i[new create]
  resources :invitations, only: %i[create destroy]
  get "invitations/:invitation_token/accept" => "invitations/acceptances#show", as: :invitation_acceptance
  post "invitations/:invitation_token/accept" => "invitations/acceptances#create"
  resources :users, only: %i[index update destroy]
  resource :ai_settings, only: %i[show update]
  resource :prompt_refresh, only: :create
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
  resources :features, only: %i[index show new create edit update] do
    scope module: :features do
      resource :spec, only: :create
      resource :launch_review, only: :create
      resource :linear_issue, only: :create
      resource :linear_simulation, only: :create
    end
  end

  resources :documents, only: %i[index show create edit update] do
    scope module: :documents do
      resources :suggestions, only: :create do
        resource :acceptance, only: :create
        resource :rejection, only: :create
      end
      resources :versions, only: %i[index show]
      resource :regeneration, only: :create
    end
  end
  resources :document_templates, only: %i[index new create edit update]
  resources :skills, except: :show
  resource :team_instructions, only: :update
  resource :profile, only: %i[show update] do
    resource :mcp_token, only: :create, module: :profiles
  end
  resources :customers, only: %i[index show]
  resources :knowledge_documents, except: :show

  resources :integrations, only: %i[index show new create update destroy] do
    scope module: :integrations do
      resource :connection_check, only: :create
      resource :sync, only: :create
      resources :simulated_messages, only: :create
    end
  end

  # Signed webhooks, no session
  namespace :slack do
    resources :events, only: :create
  end
  namespace :linear do
    resources :webhooks, only: :create
  end

  # MCP server for coding agents (bearer token from the profile page)
  match "mcp" => "mcp#handle", via: %i[get post delete]

  # The fake LiteLLM (lib/mock_llm.rb) when no LITELLM_URL is set
  mount MockLlm.new => "/mock_llm" if Rails.env.development? && Rails.configuration.x.mock_llm

  get "up" => "rails/health#show", as: :rails_health_check
end
