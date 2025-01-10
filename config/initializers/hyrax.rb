# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack
Rails.application.config.before_initialize do
  Hyrax.config do |config|
    # TODO: Valkyrize models and update this initializer
    # # Injected via `rails g hyrax:work Cdl`
    config.register_curation_concern :cdl

    # # See https://github.com/notch8/adventist-dl/issues/183
    # # Also, we will continue to extract txt file's text using Adventist::TextFileTextExtractionService
    # config.extract_full_text = false
    # config.work_requires_files = false

    # # Location autocomplete uses geonames to search for named regions.
    # # Specify the user for connecting to geonames:
    # # Register here: http://www.geonames.org/manageaccount
    # config.geonames_username = ENV.fetch('HYKU_GEONAMES_USERNAME', 'scientist')
    # # If you have ffmpeg installed and want to transcode audio and video uncomment this line
    # config.enable_ffmpeg = false

    # config.branding_path = ENV.fetch('HYRAX_BRANDING_PATH', Rails.root.join('public', 'branding'))

    config.simple_schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root)
  end
end

Rails.application.config.after_initialize do
  # Ensure that valid_child_concerns are set with all the curation concerns including
  # the ones registered from the Knapsack
  Hyrax.config.curation_concerns.each do |concern|
    concern.valid_child_concerns = Hyrax.config.curation_concerns
    "#{concern}Resource".safe_constantize&.valid_child_concerns = Hyrax.config.curation_concerns
  end
end
