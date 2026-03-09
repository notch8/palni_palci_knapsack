# frozen_string_literal: true

# Base factories so the knapsack does not load Hyrax's test harness (SimpleWork, monograph schema).
# hyrax-webapp's :hyku_work has parent :hyrax_work; we define :hyrax_work here using app classes.
# Load this first (knapsack factories before webapp) so :hyrax_work exists when webapp factories load.
FactoryBot.define do
  factory :hyrax_work, class: 'GenericWorkResource' do
    title { ['Test Work'] }
  end

  factory :hyrax_file_set, class: 'Hyrax::FileSet' do
    title { ['Test File Set'] }
  end

  factory :hyrax_file_metadata, class: 'Hyrax::FileMetadata' do
    use { [:original_file] }
  end
end
