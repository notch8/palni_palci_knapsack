# frozen_string_literal: true

# Respect Hyku's default: HYRAX_FLEXIBLE is off unless set by the app (e.g. .env, docker-compose).
# Set before engine is required so that it takes effect before other models are loaded.

ENV['HYRAX_DISABLE_INCLUDE_METADATA'] = 'true' if ENV.fetch('HYRAX_FLEXIBLE', 'true') == 'true'

require "hyku_knapsack/version"
require "hyku_knapsack/engine"

module HykuKnapsack
  # Your code goes here...
end
