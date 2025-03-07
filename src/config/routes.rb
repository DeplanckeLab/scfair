Rails.application.routes.draw do
  resources :datasets, only: :index, path: "explore"
  resources :ontology_terms, only: [:show]

  get "tools", to: "home#tools", as: :tools
  get "contact-us", to: "home#contact", as: :contact
  get "resources", to: "home#resources", as: :resources
  get "metadata-schema", to: "home#metadata_schema", as: :metadata_schema
  get "about", to: "home#about", as: :about
  get "community", to: "home#community", as: :community

  root to: "home#index"
end
