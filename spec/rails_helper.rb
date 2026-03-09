# frozen_string_literal: true

# Set environment variables BEFORE requiring Rails environment
# so initializers read the correct values on first load.
ENV["RAILS_ENV"] ||= "test"
ENV['HYRAX_FLEXIBLE'] ||= 'false'
# Mirror the env setup from hyrax-webapp/spec/rails_helper.rb so Rails initializers
# (especially analytics and routing) behave correctly in test mode.
ENV['HYKU_ADMIN_HOST'] = 'test.host'
ENV['HYKU_ROOT_HOST'] = 'test.host'
ENV['HYKU_ADMIN_ONLY_TENANT_CREATION'] = nil
ENV['HYKU_DEFAULT_HOST'] = nil
ENV['HYKU_MULTITENANT'] = 'true'
ENV['VALKYRIE_TRANSITION'] = 'true'
ENV['HYRAX_ANALYTICS_REPORTING'] = 'false'

require 'logger'
require 'active_support'

# Boot Rails FIRST (requires hyrax-webapp submodule to be present, e.g. git submodule update --init).
# This ensures HYRAX_FLEXIBLE is correctly set when Rails initializers run.
require File.expand_path("../hyrax-webapp/config/environment", __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "spec_helper"

# Valkyrie adapter registration and shared spec helpers (from hyrax-webapp when submodule is present).
hyrax_spec_dir = File.expand_path("../hyrax-webapp/spec", __dir__)
require File.join(hyrax_spec_dir, "hyrax_with_valkyrie_helper") if File.exist?(File.join(hyrax_spec_dir, "hyrax_with_valkyrie_helper.rb"))

require "rspec/rails"
require "factory_bot_rails"
require 'capybara/rails'
require 'dry-validation'
require 'database_cleaner'

# Configure Hyrax to use Valkyrie-based models in tests.
Hyrax.config.admin_set_model = "AdminSetResource"
Hyrax.config.collection_model = "CollectionResource"

# Load only knapsack and webapp factories. We do not load Hyrax's shared spec factories or
# require SimpleWork (monograph schema)—the knapsack does not run Hyrax's tests. Base factories
# (:hyrax_work, :hyrax_file_set, :hyrax_file_metadata) are defined in the knapsack so :hyku_work
# and :cdl_resource work without pulling in Hyrax's test harness.
FactoryBot.definition_file_paths = [
  File.expand_path("spec/factories", HykuKnapsack::Engine.root),
  File.expand_path("spec/factories", Rails.root)
]
FactoryBot.find_definitions

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }
Dir[HykuKnapsack::Engine.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Run only knapsack specs; exclude Hyku (submodule) specs that depend on QA authorities
  # and other Hyku-specific setup not present in the knapsack (see hyku_knapsack PR #49).
  config.exclude_pattern = 'spec/hyku_specs/**/*_spec.rb'

  config.fixture_paths = [Rails.root.join('spec', 'fixtures')]
  config.file_fixture_path = Rails.root.join('spec', 'fixtures').to_s
  config.use_transactional_fixtures = false

  config.include HykuKnapsack::Engine.routes.url_helpers
  config.include Capybara::DSL
  config.include ActionDispatch::TestProcess::FixtureFile
  config.include Fixtures::FixtureFileUpload if defined?(Fixtures::FixtureFileUpload)
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include FactoryBot::Syntax::Methods
  config.include ApplicationHelper, type: :view if defined?(ApplicationHelper)
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

# Appeasing the Hyrax user factory interface (Hyku 7 compatibility; see samvera-labs/hyku_knapsack PR #49).
# In Hyku 7, RoleMapper#add may not exist; define it to delegate to Rolify.
def RoleMapper.add(user:, groups:)
  groups.each do |group|
    user.add_role(group.to_sym, Site.instance)
  end
end
