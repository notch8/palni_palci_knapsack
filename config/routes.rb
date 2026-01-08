# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  mount Hyrax::Engine, at: '/'

  # pittir Admin Note format: /id/eprint/12345
  get '/id/eprint/:legacy_id', to: 'legacy_redirects#show', constraints: { legacy_id: /\d+/ }

  # pittir Identifier format: /12345
  get '/:legacy_id', to: 'legacy_redirects#show', constraints: { legacy_id: /\d+/ }
end
