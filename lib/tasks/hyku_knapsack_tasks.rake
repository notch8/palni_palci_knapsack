# frozen_string_literal: true

namespace :knapsack do
  namespace :db do
    desc "Run test DB migrations (host app + engine). Run from repo root so knapsack specs have work_authorizations etc."
    task :test_migrate do
      ENV["RAILS_ENV"] = "test"
      require File.expand_path("../../hyrax-webapp/config/environment", __dir__)
      Rake::Task["db:migrate"].invoke
    end
  end
end
