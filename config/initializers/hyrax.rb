# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack
HykuKnapsack::DEFAULT_M3_PROFILE_PATH = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml')

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', false))

    config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
      if config.respond_to?(:schema_loader_config_search_paths)

    config.default_m3_profile_path = HykuKnapsack::DEFAULT_M3_PROFILE_PATH \
      if config.respond_to?(:default_m3_profile_path=)

    # Injected via `rails g hyrax:work Cdl`
    config.register_curation_concern :cdl
  end

  # Ensure that valid_child_concerns are set with all the curation concerns including
  # the ones registered from the Knapsack
  Hyrax.config.curation_concerns.each do |concern|
    concern.valid_child_concerns = Hyrax.config.curation_concerns
    "#{concern}Resource".safe_constantize&.valid_child_concerns = Hyrax.config.curation_concerns
  end
end
