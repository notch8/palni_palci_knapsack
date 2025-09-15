# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength

Rails.application.config.after_initialize do
  # Add all concerns that are migrating from ActiveFedora here
  CONCERNS = [Cdl, Etd, GenericWork, Image, Oer].freeze

  CONCERNS.each do |klass|
    Wings::ModelRegistry.register("#{klass}Resource".constantize, klass)
    # we register itself so we can pre-translate the class in Freyja instead of having to translate in each query_service
    Wings::ModelRegistry.register(klass, klass)
  end

  Wings::ModelRegistry.register(CdlResource, Cdl)
  Wings::ModelRegistry.register(EtdResource, Etd)
  Wings::ModelRegistry.register(GenericWorkResource, GenericWork)
  Wings::ModelRegistry.register(ImageResource, Image)
  Wings::ModelRegistry.register(OerResource, Oer)
end
# rubocop:enable Metrics/BlockLength
