# frozen_string_literal: true

# Set environment variables BEFORE requiring Rails environment
# so initializers read the correct values on first load.
ENV["RAILS_ENV"] ||= "test"
ENV['HYRAX_FLEXIBLE'] ||= 'true'
# Mirror the env setup from hyrax-webapp/spec/rails_helper.rb so Rails initializers
# (especially analytics and routing) behave correctly in test mode.
ENV['HYKU_ADMIN_HOST'] = 'test.host'
ENV['HYKU_ROOT_HOST'] = 'test.host'
ENV['HYKU_ADMIN_ONLY_TENANT_CREATION'] = nil
ENV['HYKU_DEFAULT_HOST'] = nil
ENV['HYKU_MULTITENANT'] = 'true'
ENV['VALKYRIE_TRANSITION'] = 'true'
ENV['HYRAX_ANALYTICS_REPORTING'] = 'false'

# Boot Rails FIRST (requires hyrax-webapp submodule to be present, e.g. git submodule update --init).
# This ensures HYRAX_FLEXIBLE is correctly set when Rails initializers run.
require File.expand_path("../hyrax-webapp/config/environment", __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "spec_helper"
require "rspec/rails"
require "factory_bot_rails"
require 'capybara/rails'
require 'dry-validation'
require 'database_cleaner'

# Configure Hyrax to use Valkyrie-based models in tests.
Hyrax.config.admin_set_model = "AdminSetResource"
Hyrax.config.collection_model = "CollectionResource"

# Define a minimal Hyrax::Test::SimpleWork stub so FactoryBot can compile the :hyrax_work
# factory (which declares class: 'Hyrax::Test::SimpleWork') without loading the full
# simple_work.rb file, which triggers Wings/ActiveFedora registrations that conflict
# with Valkyrie even when HYRAX_FLEXIBLE=true.
module Hyrax
  module Test
    class SimpleWork < Hyrax::Work; end unless const_defined?(:SimpleWork)
  end
end

# Load factories from Hyrax's shared specs (defines :generic_work, :hyrax_work, etc.),
# then hyrax-webapp, then this knapsack engine (which modifies/extends them).
FactoryBot.definition_file_paths = [
  Hyrax::Engine.root.join("lib/hyrax/specs/shared_specs/factories").to_s,
  File.expand_path("spec/factories", Rails.root),
  File.expand_path("spec/factories", HykuKnapsack::Engine.root)
]
FactoryBot.find_definitions

# Appeasing the Hyrax user factory interface (Hyku 7 compatibility; see samvera-labs/hyku_knapsack PR #49).
# In Hyku 7, RoleMapper#add may not exist; define it to delegate to Rolify.
def RoleMapper.add(user:, groups:)
  groups.each do |group|
    user.add_role(group.to_sym, Site.instance)
  end
end

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }
Dir[HykuKnapsack::Engine.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec', 'fixtures')]
  config.use_transactional_fixtures = false

  config.include HykuKnapsack::Engine.routes.url_helpers
  config.include Capybara::DSL
  config.include Fixtures::FixtureFileUpload if defined?(Fixtures::FixtureFileUpload)
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include FactoryBot::Syntax::Methods
  config.include ApplicationHelper, type: :view
  config.include Warden::Test::Helpers, type: :feature
  config.include ActiveJob::TestHelper

  config.before do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end
