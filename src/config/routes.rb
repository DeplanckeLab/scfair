Rails.application.routes.draw do
  resources :datasets, only: :index, path: "explore"
  get "/facets/param_keys", to: "facets#param_keys", as: :facet_param_keys
  get "/facets/:category", to: "facets#show", as: :facet
  get "/facets/:category/children", to: "facets#children", as: :facet_children
  get "/facets/:category/search", to: "facets#search", as: :facet_search
  resources :ontology_terms, only: [:show]
  
  resources :stats, only: [:index] do
    collection do
      get ":source_id/failed_datasets", action: :failed_datasets, as: :failed_datasets
      get ":source_id/:category/parsing_issues", action: :parsing_issues, as: :parsing_issues
    end
  end

  get "tools", to: "home#tools", as: :tools
  get "contact-us", to: "home#contact", as: :contact
  get "resources", to: "home#resources", as: :resources
  get "metadata-schema", to: "home#metadata_schema", as: :metadata_schema
  get "about", to: "home#about", as: :about
  get "community", to: "home#community", as: :community
  get "contribute", to: "home#contribute", as: :contribute

  root to: "home#index"
end
