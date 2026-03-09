# frozen_string_literal: true

require "hyku_knapsack/version"
require "hyku_knapsack/engine"

ENV['HYRAX_DISABLE_INCLUDE_METADATA'] = 'true' if ENV.fetch('HYRAX_FLEXIBLE', 'false') != 'false'

module HykuKnapsack
  # Your code goes here...
end
