# frozen_string_literal: true
require 'sentry-ruby'
require 'sentry-sidekiq'

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = %w[palni-palci-knapsack-friends palni-palci-knapsack-demo palni-palci-knapsack-production]
  # Skip Hyrax 404s
  config.excluded_exceptions += ['Hyrax::ObjectNotFoundError']
  config.debug = false
end
